require 'coffeescript/register'
mailparser = require 'mailparser'
simpleParser = mailparser.simpleParser
dotenv = require 'dotenv'
# coffee seems to not find dotenv automatically.
dotenv.config({ path: __dirname + '/.env' })
emails = require './emails'
express = require 'express'
Imap = require 'imap'
app = express()
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
openInbox = (cb) ->
    imap.openBox 'INBOX', true, cb || ((err, box) -> if err then throw err)

# https://github.com/mscdex/node-imap/issues/764#issuecomment-1716322864
imap.connect()
# check for sprig@hackclub.com, login@hackclub.com ..etc
imap.on 'ready', () ->
    console.log 'Connected'
    openInbox (err, box) ->
        if err then throw err
        # imap.search ['UNSEEN'], (err, results) ->
        #     if err then throw err
        #     if results.length > 0
        #         console.log "New email"
        #     else
        #         console.log "No new email"
        setInterval openInbox, 1000

imap.on 'error', (err) ->
    console.error err
imap.on 'mail', (numNewMsgs) ->
    console.log "New mail: #{numNewMsgs}"
    imap.search ['UNSEEN', ['FROM', '@hackclub.com']], (err, results) ->
        if err then throw err
        console.log results
        if results.length > 0
            console.log "New email"
            f = imap.fetch(results, { bodies: '', markSeen: true })
            f.on 'message', (stream) ->
                stream.on 'body', (stream) ->
                    simpleParser stream, (err, mail) ->
                        if err then throw err
                        # console.log mail
                        # for email in emails
                        #     if mail.from.value[0].address is email.email
                        #         console.log "Email from #{email.email}"
                        #         console.log mail.from
                        if mail.from.value[0].address  in emails.map((email) -> email.email)
                            email = emails.find((email) -> email.email is mail.from.value[0].address)
                            console.log "Email from #{email.email}"
                            # TODO: finish this =(

            f.on 'end', ->
                console.log "Done fetching all messages"
        else
            console.log "No new email"


app.get '/health', (req, res) ->
  res.send 'OK'


if process.env.USE_SERVER is 'y'
  server = app.listen process.env.PORT || 3000, ->
    console.log "Listening on port #{process.env.PORT}"

process.on 'exit', ->
  console.log "Closing server"





