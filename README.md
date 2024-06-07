# EmojiSync

Sync your custom emojis from Slack to GitLab.

## Running

**Configuration**

The following variables are available for configuration
| variable | required |
| -------- | -------- |
| GITLAB_ACCESS_TOKEN | yes |
| GITLAB_GROUP_PATH | yes |
| SLACK_ACCESS_TOKEN | yes |
| GITLAB_HOSTNAME | no | 


## Development

- Configure the above env variables
- Run `mix deps.get`
- Run `mix` to run the sync

**todo**
- Dockerize for simpler running
- Understand how to make the config env variables _required_
- Make it more efficient by also fetching the existing emojis from GitLab and only try creating the diff