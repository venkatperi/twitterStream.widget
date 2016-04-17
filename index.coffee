url: "ws://192.168.0.10:10017/"
ws: {}
timeout: 5000
$el: {}
commonDir: "./common"
command: ""
refreshFrequency: false

render: (output) ->
  """
    <style>
      @import url(#{@commonDir}/font-awesome/css/font-awesome.css);
    </style>
    <script src="#{@commonDir}/moment-min-js"></script>
    <table id="tweets">
      <tbody></tbody>
    </table>
  """

afterRender: (el) ->
  @$el = $(el)
  $(el).ready =>
    @openWebSocket()
    setInterval  ( => @openWebSocket()), @timeout * 5 # watchdog

openWebSocket: ->
  return if @ws.readyState is 1 #open
  try
    @ws = new WebSocket(@url)
    @ws.onopen = => @onWSOpen()
    @ws.onclose = => @onWSClose()
    @ws.onerror = (e) => @onWSError e
    @ws.onmessage = (e) => @onWSMessage e
  catch err
    console.log "error opening websocket to #{@url}", err

retryOpenWS: ->
  console.log "retrying open websocket in #{@timeout}ms"
  setTimeout (=> @openWebSocket()), @timeout

onWSOpen: ->
  console.log "websocket opened"
  sub = command: "SUBSCRIBE", channels: ["TWEET"]
  @ws.send JSON.stringify(sub)

onWSClose: ->
  console.log "websocket closed"
  @retryOpenWS()

onWSError: (e) ->
  console.log "websocket error: #{e}"
  @retryOpenWS()

onWSMessage: (e) ->
  msg = JSON.parse e.data
  return unless msg.channel? && msg.channel == "TWEET"
  @onTweet msg.message

onTweet: (t) ->
  text = t.retweeted_status?.text or t.text
  entities = t.retweeted_status?.entities or t.entities
  createdAt = moment(t.created_at)
  user = t.retweeted_status?.user or t.user

  row = """
<tr>
<td class="profile-image recent">
  <div>
    <a href="https://twitter.com/#{user.screen_name}">
      <img src="#{user.profile_image_url}"
        data-url="https://twitter.com/#{user.screen_name}">
    </a>
  </div>
  <div class="time">
    #{createdAt.format("h:mm a")}
  </div>
</td>"""

  row += """
<td class="message recent">
  <div class="user">
    <div>
      <span class="screen-name">#{t.user.name}</span>
      <div class="username">@#{t.user.screen_name}</div>
    </div>
  </div>
 """

  if t.retweeted_status?
    row += """
  <div class="retweeted_from">
    <span class="rt">RT from:</span> @#{t.retweeted_status.user.screen_name}
  </div>"""

  if entities.media?.length
    m = entities.media[0]
    text = text.replace m.url, ""

    row += """
  <div class="photo" >
    <a href="#{m.url}">
      <img src="#{m.media_url}" id="photo_#{t.id}">
    </a>
  </div>"""

  if entities.urls?.length
    for c in entities.urls
      text = text.replace c.url, "&nbsp;<a class='link'
        href='#{c.url}'><i class='fa fa-external-link-square'></i></a>&nbsp;"

  if  entities.hashtags?.length
    for c in entities.hashtags
      text = text.replace "##{c.text}", "<a
        class=\"hashtag\"
        href=\"https://twitter.com/search?q=%23#{c.text}\">##{c.text}</a>"

  if  entities.user_mentions?.length
    for c in entities.user_mentions
      text = text.replace "@#{c.screen_name}",
        "<a class=\"mention\"
        href=\"https://twitter.com/#{c.screen_name}\">@#{c.screen_name}</a>"

  row += """
     <div class='text' lang='en'>#{text}</div>
   </div>
  </td>
</tr>"""

  @$el.find("tbody:first-child").prepend row
  @$el.find("tbody:nth-child(n+10)").remove()
  setTimeout (=> @$el.find(".recent").removeClass "recent"), 100

style: """
  background: black
  -webkit-font-smoothing antialiased
  font-family: "Helvetica", sans-serif
  font-size: 14px
  font-weight 300
  left: 0px
  top: 0px
  overflow: hidden
  max-height: 89%
  width: 225px

  #tweets
    width: 225px
    color: #909090
    border-collapse collapse

    td
      background-color black
      -webkit-transition background-color 2s
      transition: background-color 2s
      position: relative
      vertical-align: top
      border-bottom: solid 1px #252525
      padding 6px 0

      &.recent
        background-color #404040

    .profile-image
      width: 35px
      padding-right: 3px

    .message
      max-width 170px

    .user
      font-size: 12px
      overflow: hidden
      margin-top -3px
      display -webkit-flex
      display -moz-flex
      display flex

      .screen-name
        float: left
        -webkit-flex: 1
        -moz-flex: 1
        flex: 1
        color: #a0a0a0
        font-weight: 600
        margin-right 5px

      .username
        color: #8799A5
        white-space nowrap
        overflow hidden
        text-overflow ellipsis
        min-width 20px

    .retweeted_from
      font-size: 11px
      overflow: hidden
      .username
        color: #8799A5
      .rt
        color: #808080
        font-weight 600

    .text
      font-size: 13px
      -webkit-hyphens: auto
      -moz-hyphens: auto
      -ms-hyphens: auto
      hyphens auto
      margin-top 4px

      a, .link, .mention, .hashtag
        text-decoration none
        color #7BB0CC

      .link i
        font-size 12px

    .time
      font-size: 11px
      font-weight 600
      text-align center
      color: #808080
      margin-top 3px

    .photo
      height: 75px
      overflow hidden
      margin-bottom 6px
      margin-top 6px
      img
        max-width: 100%

"""

relativeTime: (timeAgo) ->
  seconds = Math.floor((new Date - timeAgo) / 1000)
  intervals = [
    Math.floor(seconds / 31536000)
    Math.floor(seconds / 2592000)
    Math.floor(seconds / 86400)
    Math.floor(seconds / 3600)
    Math.floor(seconds / 60)
  ]
  times = [
    'y'
    'mo'
    'd'
    'h'
    'm'
  ]
  for key of intervals
    return intervals[key] + ' ' + times[key]
  Math.floor(seconds) + ' s'
