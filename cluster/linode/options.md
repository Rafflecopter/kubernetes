# Linode specific configuration options

These options can be set as environment variables to customize how your cluster is created.  Only options
specific to Linode are documented here, for cross-provider options see [this document](../options.md).

This is a work-in-progress; not all options are documented yet!

**LINODE_APIKEY**

Your Linode API Key. This is required.

**LINODE_DISTRIBUTION**

Distribution to deploy.

- `vivid` Ubuntu 15.04 (default)
- `trusty` Ubuntu 14.04 LTS
- `jessie` Debian 8.1

**LINODE_DATACENTER**

Datacenter to deploy the cluster to. Use abbreviations of the datacenters, such as `dallas` for Dallas, TX, USA. See all datacenters by using the Linode API action: `avail.datacenters`. Default is `newark`.


**MASTER_SIZE**, **MINION_SIZE**

The linode size to use for creating the master/minion.  Defaults to `1024` (for Linode size 1024).

For production usage, we recommend bigger instances, for example:

```
export MASTER_SIZE=4096
export MINION_SIZE=8192
```