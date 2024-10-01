require 'coffeescript/register'
mailparser = require 'mailparser'
simpleParser = mailparser.simpleParser
dotenv = require 'dotenv'
clipboardy = require 'clipboardy-cjs'
# coffee seems to not find dotenv automatically.
dotenv.config({ path: __dirname + '/.env' })
emails = require './emails'
express = require 'express'
Imap = require 'imap'
app = express()
current_codes = []
imap = new Imap({
    user: process.env.IMAP_USER,
    password: process.env.IMAP_PASSWORD,
    host: process.env.IMAP_HOST,
    port: process.env.IMAP_PORT,
    tls: true,
    keepAlive: true,
    authTimeout: 100000,
    connTimeout: 100000,
})
manageCode = (codeOrUrl) ->
    if !codeOrUrl
        return
    if typeof codeOrUrl is not 'string'
        console.log "Code is not a string"
        return
    if !codeOrUrl.startsWith
        console.log "Code is not a string"
        return
    if codeOrUrl.length < 3
        console.log "Code too short"
        return
    if codeOrUrl.length > 10 && !codeOrUrl.startsWith('http')
        console.log "Code too long"
        return
    console.log "Copied #{codeOrUrl} to clipboard"
    current_codes.push codeOrUrl
    if process.env.USE_CLIPBOARD == 'y'
        if codeOrUrl.startsWith('http')
            require('open')(codeOrUrl)
        else
            try
                clipboardy.default.writeSync(codeOrUrl)
            catch e
                console.error e

    if process.env.NTFY_TOPIC_NAME != null
        fetch (process.env.NTFY_HOST || "https://ntfy.sh") + '/' + process.env.NTFY_TOPIC_NAME, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Click': codeOrUrl if codeOrUrl.startsWith('http')
            },
            body: if codeOrUrl.startsWith("http") then "Click on me to open your verification url." else "Your verification code is " + codeOrUrl,
        }

openInbox = (cb) ->
    # WHY DOES the t/f actually matter?
    # =(
    # @see https://github.com/mscdex/node-imap/issues/430#issuecomment-59636298
    imap.openBox 'INBOX', false, cb || ((err, box) -> if err then throw err)

# https://github.com/mscdex/node-imap/issues/764#issuecomment-1716322864
imap.connect()
# check for sprig@hackclub.com, login@hackclub.com ..etc
imap.on 'ready', () ->
    console.log 'Connected'
    openInbox (err, box) ->
        if err then throw err
        setInterval openInbox, 1000

imap.on 'error', (err) ->
    console.error err
imap.on 'mail', (numNewMsgs) ->
    console.log "New mail: #{numNewMsgs}"
    imap.search ['UNSEEN', ['FROM', '@hackclub.com']], (err, results) ->
        if err then throw err
        if results.length > 0
            console.log "New email"
            f = imap.fetch(results, { bodies: '', markSeen: true })
            f.on 'message', (mstream) ->
                mstream.on 'body', (stream) ->
                    simpleParser stream, (err, mail) ->
                        if err then throw err
                        parseSprig = (mail) ->
                            code = mail.text.split("Here's your Sprig login code: ")[1].split("\n")[0]
                            console.log code, 'code'
                            manageCode(code)
                        parseLogin = (mail) ->
                            code = mail.text.split('\n')[4]
                            console.log code, 'code'
                            manageCode(code)
                        parseTeam = (mail) ->
                            code = mail.text.split('\n')[4].split("It's here: ")[1]
                            console.log code, 'code'
                            manageCode(code)
                        if mail.from.value[0].address  in emails.map((email) -> email.email)
                            email = emails.find((email) -> email.email is mail.from.value[0].address)
                            console.log "Email from #{email.email}"
                            switch email.email
                                when 'team@hackclub.com' then parseTeam(mail)
                                when 'login@hackclub.com' then parseLogin(mail)
                                when 'sprig@hackclub.com' then parseSprig(mail)
                            # console.log mail.text
                mstream.on 'attributes', (attrs) ->
                    console.log 'Attributes:', attrs
                    uid = attrs.uid
                    imap.addFlags(uid, ['\\Seen'], (err) -> if err then throw err else console.log 'Marked as seen 2')
            f.on 'end', ->
                console.log "Done fetching all messages ", results
                imap.setFlags results, ['\\Seen'], (err) ->
                    if err then throw err
                    console.log('Marked as read')
        else
            console.log "No new email"


app.get '/health', (req, res) ->
  res.send 'OK'
app.get '/', (req, res) ->
  mapFunc = (c) -> if c.startsWith('http') then "<a href='#{c}'>#{c}</a>" else c
  res.send current_codes.map(mapFunc).join('<br>')

if process.env.USE_SERVER is 'y'
  server = app.listen process.env.PORT || 3000, ->
    console.log "Listening on port #{process.env.PORT}"

process.on 'exit', ->
  console.log "Closing server"
