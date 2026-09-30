"""Weekly, fail-closed native volume backups with no automatic expiry."""

import datetime as dt
import json
import os

OWNER = "personal-gitops-fns"


def decide(backups, now, limit):
    if limit < 2:
        raise ValueError("Rotation requires at least two recovery points")
    live = [b for b in backups if b.lifecycle_state != "TERMINATED"]
    if len(live) > limit:
        raise RuntimeError("Unexpected backup count; refusing automatic deletion")
    if any(b.lifecycle_state != "AVAILABLE" for b in live):
        return "wait", None
    ordered = sorted(live, key=lambda b: (b.time_created, b.id))
    if ordered and now - ordered[-1].time_created < dt.timedelta(days=7):
        return "current", None
    if len(ordered) == limit:
        return "delete", ordered[0].id
    return "create", None


def handler(ctx, data=None):
    import oci
    from fdk import response

    signer = oci.auth.signers.get_resource_principals_signer()
    block = oci.core.BlockstorageClient({}, signer=signer)
    objects = oci.object_storage.ObjectStorageClient({}, signer=signer)
    namespace, bucket = os.environ["NAMESPACE"], os.environ["BUCKET"]
    volume_id = os.environ["VOLUME_ID"]
    lock = "rotation.lock"
    try:
        objects.put_object(
            namespace, bucket, lock, b"rotation in progress", if_none_match="*"
        )
    except oci.exceptions.ServiceError as exc:
        if exc.status == 412:
            raise RuntimeError(
                "Rotation locked; inspect prior invocation before unlocking"
            ) from exc
        raise

    # Ambiguous API errors deliberately leave the lock for human inspection.
    volume = block.get_volume(volume_id).data
    if volume.compartment_id != os.environ["SOURCE_COMPARTMENT_ID"]:
        raise RuntimeError("Unexpected source compartment")
    backups = oci.pagination.list_call_get_all_results(
        block.list_volume_backups,
        compartment_id=volume.compartment_id,
        volume_id=volume_id,
    ).data
    owned = [b for b in backups if b.lifecycle_state != "TERMINATED"]
    if any((b.freeform_tags or {}).get("managed-by") != OWNER for b in owned):
        raise RuntimeError("Unmanaged source backups present; reconcile manually")
    now = dt.datetime.now(dt.timezone.utc)
    action, backup_id = decide(owned, now, int(os.environ["BACKUP_LIMIT"]))
    catalog = {
        "checked_at": now.isoformat(),
        "volume_id": volume_id,
        "availability_domain": volume.availability_domain,
        "namespace": "fns",
        "pvc": "fns-data",
        "action": action,
        "backups": [oci.util.to_dict(b) for b in owned],
    }
    objects.put_object(namespace, bucket, "catalog.json", json.dumps(catalog).encode())
    if action == "delete":
        candidate = block.get_volume_backup(backup_id).data
        if candidate.lifecycle_state != "AVAILABLE" or candidate.volume_id != volume_id:
            raise RuntimeError("Backup changed during rotation")
        block.delete_volume_backup(backup_id)
    elif action == "create":
        result = block.create_volume_backup(
            oci.core.models.CreateVolumeBackupDetails(
                volume_id=volume_id,
                type="INCREMENTAL",
                display_name=f"fns-{now:%Y-%m-%d}",
                freeform_tags={"managed-by": OWNER},
            ),
            opc_retry_token=f"fns-{now:%Y-%m-%d}",
        )
        catalog["requested_backup_id"] = result.data.id
        objects.put_object(
            namespace, bucket, "catalog.json", json.dumps(catalog).encode()
        )
    print(json.dumps({"action": action, "volume_id": volume_id}))
    objects.delete_object(namespace, bucket, lock)
    return response.Response(
        ctx,
        response_data=json.dumps({"action": action}),
        headers={"Content-Type": "application/json"},
    )
