# Runcloud.io rc-backup.sh script
The state of this software is beta AKA works fine for me using RunCloud servers
based on Ubuntu 20.04.2 LTS and the Litespeed stack.

I have not tested it on any other runcloud server options - if you do please
leave feedback.

## Why I made this backup script
The backup service provided by runcloud is excellent, except:

- it's very expensive in my use case (100 APPS = $100 plus +
  storage costs each month)
- you have to schedule each APP backup indivually

## Goals of this script:

Completed:
- Set and forget
- Use a cheap storage provider (Wasabi buckets are $6 per TB)
- FULL backup of each APP monthly
- DIFFERENTIAL backup of each APP as often as you'd like (default nightly)
- Excellent compression via 7zip
- Stores LOCAL backup on the server
- Store OFFSITE backup externally to S3 provider
- Easy restores from CLI to the same or a different domain
- Compatability with static and Wordpress sites
- Uses static binaries from it's own directory (no server changes)
- Trival to uninstall / delete with no changes to your server
- Logging
- Easy manual restore of files to any server
- WP restore script included (works on runcloud servers)

Todo:
- Allerts via email
- Local and remote pruning of backups, not urgent for me as storage is cheap!

## Pre-requsits
- runcloud.io account
- At least one server managed by your runcloud.io account that you wanto backup
- Somewhere to store the backups E.g an S3 compatible bucket
- Root access to the runcloud server instance *

## Quick install
Visit your S3 backup provider of choice and create a bucket, user and policy. Save the [access-key] and [secret-key]  for use in the next step.

ssh to your runcloud managed server
```bash
ssh root@xxx.xxx.xxx.xxx
cd /root
git clone xxxxx
cd rc-backup
```

Setup your s3 bucket with the minio client app:
```bash
bin/mc config host add s3backup https://s3.wasabisys.com [access-key] [secret-key] 
```

Run your first backup to make sure everything works:
```bash
./rc-backup
```

Schedule the script to run nightly
```bash
crontab -e
```
And paste in a schedule (this is for 2am each night)
`0 2 * * * /bin/bash /root/rc-backup/rc-backup.sh`

# Un-installing
Delete the schedule from cron
```bash
crontab -e
```
Delete the rc-backup folder from ~/root
```bash
cd /
rm -rf /root/rc-backup
```

# Notes
**Note** If you created the server using the DigitalOcean API integration from
Runcloud you probably don't have the root password. You can reset it by loggin
into DigialOcean, selecting the droplet and chooseing reset root password - it
will be emailed to your DO regitistered email account and will need to be reset
upon first login.
