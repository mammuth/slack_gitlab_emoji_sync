import Config

config :emoji_sync,
  gitlab_access_token: System.get_env("GITLAB_ACCESS_TOKEN"),
  gitlab_group_path: System.get_env("GITLAB_GROUP_PATH"),
  slack_access_token: System.get_env("SLACK_ACCESS_TOKEN"),
  gitlab_hostname: System.get_env("GITLAB_HOSTNAME", "gitlab.com")
