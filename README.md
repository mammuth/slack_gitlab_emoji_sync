# EmojiSync

Sync your custom emojis from Slack to GitLab.

## Running

- Via docker: Use the pre-built dockerhub image `mammuth/slack_gitlab_emoji_sync` or build it yourself: `docker build -t emoji_sync . && docker run -it --rm emoji_sync`
- Via mix: See the section "Development"

**Configuration**

The following variables are available for configuration

| variable | required |
| -------- | -------- |
| GITLAB_ACCESS_TOKEN | yes |
| GITLAB_GROUP_PATH | yes |
| SLACK_ACCESS_TOKEN | yes |
| GITLAB_HOSTNAME | no | 

**Example GitLab pipeline job**

```yml
slack_gitlab_emoji_sync:
  image: docker.io/mammuth/slack_gitlab_emoji_sync:latest
  stage: build
  before_script:
    # define those in your pipeline variable settings
    - export SLACK_ACCESS_TOKEN=$EMOJI_SYNC_SLACK_ACCESS_TOKEN
    - export GITLAB_ACCESS_TOKEN=$EMOJI_SYNC_GITLAB_ACCESS_TOKEN
    - export GITLAB_GROUP_PATH=$EMOJI_SYNC_GITLAB_GROUP_PATH
  script:
    - cd /app
    - mix run
  rules:
    # optional but let's you create a scheduled pipeline that only runs this job by passing a PIPELINE="slack_gitlab_emoji_sync" env variable
    - if: '$PIPELINE == "slack_gitlab_emoji_sync"'
```

## Development

- Configure the above env variables
- Run `mix deps.get`
- Run `mix run` to run the sync

**todo**
- Dockerize for simpler running
- Understand how to make the config env variables _required_
- Make it more efficient by also fetching the existing emojis from GitLab and only try creating the diff

## Known limitations
GitLab wouldn't be GitLab without a bug or annoyance in every single functionality:    
One can upload a high number of emojis (I tested it with ~400) but the frontend will only show the first 100 in the emoji pickers and markdown auto-complete via `:emoji-name:` 🫠
