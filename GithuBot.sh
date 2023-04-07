#! /bin/bash

# 钉钉机器人的 webhook 地址
webhook_url="https://oapi.dingtalk.com/robot/send?access_token=7c9546f7a6b510ce998b6e758405863f4197484b2a75ab5ac7cc6a7ee01a46b4"

# 从 GitHub Webhooks 中提取信息
read -r header
read -r payload

# 将信息格式化为 JSON
json="{\"msgtype\":\"text\",\"text\":{\"content\":\""

# 解析 JSON 中的信息
pusher=$(echo $payload | jq -r .pusher.name)
repo=$(echo $payload | jq -r .repository.name)
added=$(echo $payload | jq -r .commits[].added[])

# 构建要发送到钉钉的消息
message="$pusher 推送了 $added 到 $repo"
json="$json$message\"}}"

# 发送消息到钉钉机器人
curl -s -H "Content-Type: application/json" -d "$json" "$webhook_url" > /dev/null

echo "消息发送成功"
