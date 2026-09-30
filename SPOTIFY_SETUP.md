# Spotify設定

Spotifyプレイリスト作成機能を実機で利用する前に、Spotify Developer Dashboardで次を設定します。

1. Spotify Developer Dashboardでアプリを作成する。
2. iOS Bundle IDに `app.taira.komugi.Passing` を設定する。
3. Redirect URIに `passing-spotify-login://callback` を追加する。
4. Xcodeでターゲットの Build Settings を開く。
5. `SPOTIFY_CLIENT_ID`へSpotifyアプリのClient IDを設定する。DebugとReleaseの両方へ設定する。

Client SecretはiPhoneアプリへ保存しません。認証にはAuthorization Code with PKCEを使用します。
認証完了後にWeb APIでプレイリストを作成し、Spotifyアプリで作成済みプレイリストを開きます。
`Info.plist`の`LSApplicationQueriesSchemes`には`spotify`を登録済みです。

- App settings: https://developer.spotify.com/documentation/web-api/concepts/apps
- PKCE: https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
- Create Playlist: https://developer.spotify.com/documentation/web-api/reference/create-playlist
- Add Items: https://developer.spotify.com/documentation/web-api/reference/add-items-to-playlist
