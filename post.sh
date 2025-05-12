#!/bin/bash

# Twitter OAuth2認証と画像付き投稿のシェルスクリプト
# スコープの設定
SCOPE="tweet.read tweet.write users.read offline.access media.write"

# Twitter APIのクライアントIDとクライアントシークレットとリダイレクトURLをconfig.iniから読み込む
CONFIG_FILE="config.ini"
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "config.iniが見つかりません。クライアントIDとクライアントシークレット、リダイレクトURLを設定してください。"
  exit 1
fi
source "${CONFIG_FILE}"
if [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ] || [ -z "${REDIRECT_URI}" ]; then
  echo "config.iniにクライアントID、クライアントシークレット、リダイレクトURLを設定してください。"
  exit 1
fi

# 認証URLを開く
function open_auth_url() {
  local auth_url="https://twitter.com/i/oauth2/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&state=state&code_challenge=challenge&code_challenge_method=plain"
  
  echo "ブラウザで以下のURLを開いて認証してください:"
  echo "${auth_url}"
  echo ""
  
  # macOSでデフォルトブラウザを開く
  open "${auth_url}"
  
  echo "リダイレクトURLからcodeパラメータの値をコピーして、以下のプロンプトに貼り付けてください。"
  echo "例: https://auth.angel-sandbox.com/oauth2/idpresponse/?state=state&code=xxxxxxxxxxxx"
  echo ""
  read -p "認証コードを入力してください: " AUTH_CODE
}

# アクセストークンを取得
function get_access_token() {
  local auth_basic=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)
  
  echo "アクセストークンを取得中..."
  
  local response=$(curl --silent --location --request POST 'https://api.twitter.com/2/oauth2/token' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --header "Authorization: Basic ${auth_basic}" \
    --data-urlencode "code=${AUTH_CODE}" \
    --data-urlencode 'grant_type=authorization_code' \
    --data-urlencode "redirect_uri=${REDIRECT_URI}" \
    --data-urlencode 'code_verifier=challenge')
  
  ACCESS_TOKEN=$(echo "${response}" | jq -r '.access_token')
  
  if [ -z "${ACCESS_TOKEN}" ] || [ "${ACCESS_TOKEN}" = "null" ]; then
    echo "アクセストークンの取得に失敗しました"
    echo "レスポンス: ${response}"
    exit 1
  fi
  
  echo "アクセストークンを取得しました"
}

# 画像をアップロード
function upload_media() {
  local image_file="$1"
  
  if [ ! -f "${image_file}" ]; then
    echo "画像ファイルが見つかりません: ${image_file}"
    exit 1
  fi
  
  echo "画像をアップロード中: ${image_file}"
  
  local response=$(curl --silent -X POST 'https://api.twitter.com/2/media/upload' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    -F "media=@\"${image_file}\"")
  
  MEDIA_ID=$(echo "${response}" | jq -r '.id')
  
  if [ -z "${MEDIA_ID}" ] || [ "${MEDIA_ID}" = "null" ]; then
    echo "画像のアップロードに失敗しました"
    echo "レスポンス: ${response}"
    exit 1
  fi
  
  echo "画像をアップロードしました。メディアID: ${MEDIA_ID}"
}

# 画像付きツイートを投稿
function post_tweet_with_media() {
  local text="$1"
  
  echo "ツイートを投稿中..."
  
  local response=$(curl --silent -X POST 'https://api.twitter.com/2/tweets' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header 'Content-Type: application/json' \
    --data "{
      \"text\": \"${text}\",
      \"media\": {
        \"media_ids\": [\"${MEDIA_ID}\"]
      }
    }")
  
  local tweet_id=$(echo "${response}" | jq -r '.data.id')
  
  if [ -z "${tweet_id}" ] || [ "${tweet_id}" = "null" ]; then
    echo "ツイートの投稿に失敗しました"
    echo "レスポンス: ${response}"
    exit 1
  fi
  
  echo "ツイートを投稿しました！"
  echo "ツイートURL: https://twitter.com/i/status/${tweet_id}"
}

# メイン処理
function main() {
  # jqコマンドがインストールされているか確認
  if ! command -v jq &> /dev/null; then
    echo "jqコマンドが見つかりません。Homebrewでインストールしてください:"
    echo "brew install jq"
    exit 1
  fi
  
  # 認証コードを取得
  open_auth_url
  
  # アクセストークンを取得
  get_access_token
  
  # 画像ファイルを指定
  read -p "アップロードする画像ファイルのパスを入力してください: " IMAGE_FILE
  
  # 画像をアップロード
  upload_media "${IMAGE_FILE}"
  
  # ツイート本文を入力
  read -p "ツイート本文を入力してください: " TWEET_TEXT
  
  # ツイートを投稿
  post_tweet_with_media "${TWEET_TEXT}"
}

# スクリプトを実行
main