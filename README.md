# Runcloud.io rc-backup.sh script

## Why I made this backup script
The backup service provided by runcloud is excellent, except:

- it's very expensive (100 APPS = $100+storage costs each month)
- you have to schedule each APP backup indivually

## Goals of this script:
- Set and forget
- Use a cheap storage provider (Wasabi buckets are $5 per TB)
- Schedule a FULL backup of each APP monthly
- Schedule a DIFFERENTIAL backup of each APP nightly
- Excellent compression
- Store LOCAL backup on the server
- Store OFFSITE backup externally to S3
- Easy restores from CLI to the same or a different domain
- Compatability with static and Wordpress sites
- Logging
- Allerts via email

## Pre-requsits
- runcloud.io account
- At least one server managed by your runcloud.io account that you wanto backup
- Somewhere to store the backups E.g an S3 compatible bucket
- Root access to the runcloud server instance *

## Quick install
Visit your S3 backup provider of choice and create a bucket, user and policy. Save the access-key and secret-key for use in the next step.

ssh to your runcloud managed server
```bash
ssh root@xxx.xxx.xxx.xxx
cd /root
git clone xxxxx
cd rc-backup
```

Setup your s3 bucket with the minio client app:
```bash
/bin/mc config host add s3backup https://s3.wasabisys.com [access-key] [secret-key] 
```

Run your first backup to make sure everything works:
```bash
./rc-backup
```

Schedule the script to run nightly
```bash
crontab -e
```
And paste in schedule (this is 2am each night)
`0 2 * * * /bin/bash /root/rc-backup/rc-backup.sh`

## Wordpress backup
To backup WP use either WP-CLI plus tar.gz for files or a WP plugin.

**All-in-one-WP-Migrate command line plugin** - this generates a full site backup with the files a DB included. It can be easily restored to the same domain or a different one using either the GUI or CLI version of the tool.

## Offsite storage
Use Minio client (single binary) to connect to a S3 compatible stroage and copy in the files, keeping x number of copies. Minio support copy/move/delete operations.

**Note** If you created the server using the DigitalOcean API integration from Runcloud you probably don't have the root password. You can reset it by loggin into DO, selecting the droplet and chooseing reset root password - it will be emailed to your DO regitister email account and will need to be reset upon first login.

## scheduling backups
Use runcloud.io's excellent cron option
- Login to runcloud.io
- Select the server
- Create
- Name the job (rc-backup-nightly-3am)
- User: root
- Vendor binary (default) `/bin/bash`
- Command: `/root/rc-backup/rc-backup.sh`
- Predefined setting: Choose a schedule - I chose "at midnight"
- Edit the hour to 3
- Check prview cronjob at bottom

`0 3 * * * /bin/bash /root/rc-backup/rc-backup.sh`


