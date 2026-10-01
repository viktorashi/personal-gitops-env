# Free-tier audit — 2026-10-01

**Not certified for permanent operation on an unupgraded account.** A successful
plan or access during the trial does not prove post-trial service eligibility.
Allowances are tenancy-wide; other resources consume the same allowances.

| Component | Configured usage | Assessment |
| --- | --- | --- |
| A1 worker | 2 OCPUs, 12 GB | 31 days: 1,488 OCPU-hours / 8,928 GB-hours; within 1,500 / 9,000. |
| Block storage | 50 GB boot + 50 GB data, balanced | Within 200 GB; one 50 GB restore volume also fits. |
| Volume backups | At most five, no expiry | Fits five combined boot/data backups; no other backup policy. |
| Flexible LB | One, minimum = maximum = 10 Mbps | Matches the Always Free shape. |
| Object Storage | Two versioned Standard buckets | Size is not bounded. Old state/catalog/lock versions accumulate. |
| Basic OKE | One basic control plane | Price list says free; unupgraded post-trial access remains unverified. |
| Functions | 256 MB, hourly, timeout 120 seconds | 744 scheduled calls / 22,320 GB-seconds at timeout; below free usage. |
| Resource Scheduler | One hourly schedule | No separate price found; post-trial eligibility unverified. |
| Network/IAM | One VCN, two subnets, gateways, policies, Default domain | No paid domain edition, NAT, DNS zone or premium feature requested. |
| Argo/FNS | Run on the worker | No separate OCI compute allocation. |
| GitHub | Public repository, standard hosted runners | No paid runner or artifact storage requested. |

Functions' published allowance is 2 million calls and 400,000 GB-seconds monthly,
but that is not confirmation of access on an expired, unupgraded trial. Retries
and manual invocations also count. No provisioned concurrency is configured.
OKE and Functions need that eligibility confirmed before this design is accepted.

Object Storage allows 20 GB combined after an unupgraded trial, with 50,000 requests
per month. Trial/paid tier allowances differ: keep Standard storage below 10 GB.
The hourly backup job normally makes about 2,232 object requests per 31-day month,
plus an extra catalog write when creating a backup; state operations add usage.
No object lifecycle deletes are configured. Outbound traffic has a 10 TB/month
free allowance. Neither accumulated storage nor total traffic has a hard cap here.

## Why this still needs attention

- Oracle may reclaim idle free VMs after seven days; free accounts have no SLA.
- Pinned Kubernetes, worker images, Argo, FNS and Functions runtimes need updates.
- Backup API ambiguity deliberately leaves a lock for manual inspection. Failed
  backups currently have no configured alert; restore testing is still required.
- Data can fill its volume; versioned objects can exhaust their free allowance.
- Quotas are not a billing cap. An unupgraded account avoids paid billing but can
  lose access/resources when trial-only entitlements end.

The LB supplies an IP, not an Oracle application URL. See [endpoint setup](../cluster/README.md).
It remains stable while that LB exists; replacement can change it. HTTP provides
no transport encryption. No endpoint has been provisioned yet.

Sources: [Always Free allowances][free], [account/reclamation FAQ][faq],
[Basic OKE and Functions prices][prices], [LB addressing][lb],
[Scheduler documentation][scheduler].

[free]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
[faq]: https://www.oracle.com/cloud/free/faq/
[prices]: https://www.oracle.com/cloud/price-list/#pricing-containers
[lb]: https://docs.oracle.com/en-us/iaas/Content/Balance/Concepts/load_balancer_types.htm
[scheduler]: https://docs.oracle.com/en-us/iaas/Content/resource-scheduler/concepts/resourcescheduleroverview-about.htm
