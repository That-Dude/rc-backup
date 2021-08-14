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
- Store OFFSITE backup externally to S3 provider (using Minio client)
- Easy restores from CLI to the same or a different domain
- Compatability with static and Wordpress sites
- Uses static binaries from it's own directory (no server changes)
- Trival to uninstall / delete with no changes to your server
- Logging
- Easy manual restore of files to any server
- WP restore script included (works on runcloud servers)
- Optinally excludes files you don't want see ```exclude.lst```

Todo:
- Allerts via email
- Local and remote pruning of backups, not urgent for me as storage is cheap!

## Pre-requsits
- runcloud.io account
- At least one server managed by your runcloud.io account that you wanto backup
- Somewhere to store the backups E.g an S3 compatible bucket
- Root access to the runcloud server instance *

## Install
Visit your S3 backup provider of choice and create a bucket [bucket-name], user
and policy - see futher down for an example using Wasabi.

Save the [access-key] and [secret-key]  for use in the next step.

ssh to your runcloud managed server
```bash
ssh root@xxx.xxx.xxx.xxx
cd /root
git clone https://github.com/That-Dude/rc-backup.git
cd rc-backup
chmod +x *.sh
./rc-backup.sh
```
The first time the script is run it will download the static binaries and save
them in the bin directorty.

Configure the minio client to use your S3 bucket:
```bash
bin/mc config host add s3backup https://s3.wasabisys.com [access-key] [secret-key]
```
Edit the rc-backup.sh script and change the line:
```_target_bucket="s3backup/rcuser1-bucket/"``` to the reflect the name of your
bucket.

Run your first backup to make sure everything works.
The inital backup will take while depending on the size of your APPs, future
'differential' backups are quick.
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

# Wasabi - creating a bucket and setting up the user/policy

## Create a bucket

Crate a new bucket for this runcloud server instance to store backups, name it something like: rcuser1-bucket

## Create a policy for the user/bucket combo
**Policies -> Create Policy**

Name it: rcuser1-limit

Policy: (note the "rcuser1\*" variable!)

```json
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Sid": "ListMy",
 "Effect": "Allow",
 "Action": "s3:ListAllMyBuckets",
 "Resource": "arn:aws:s3:::*"
 },
 {
 "Sid": "AllowAll-S3ActionsToOwnBucket",
 "Effect": "Allow",
 "Action": "s3:*",
 "Resource":"arn:aws:s3:::rcuser1*"
 }
 ]
}
```

## Create a user for this bucket
**Users -> Create user**

e.g. rcuser1

Select: Programmatic (create API key)

Next: assign to 'runclud-user-group'

Next: attached policy: rcuser1-limit

Select: Create user

"Create new access keys" will appear

Chose: Copy keys to clipboard and save in password manager
