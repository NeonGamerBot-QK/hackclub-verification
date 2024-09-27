fs = require 'fs'
path = require 'path'

prompt = (question, callback) ->
    return new Promise (resolve, reject) ->
        process.stdout.write question
        process.stdin.resume()
        process.stdin.once 'data', (data) ->
            data = data.toString().trim()
            resolve data
            callback? data
        process.stdin.once 'error', (err) ->
            reject err
            callback? err
keys = {
    IMAP_USER: 'IMAP username',
    IMAP_PASSWORD: 'IMAP password',
    IMAP_HOST: 'IMAP host',
    IMAP_PORT: 'IMAP port',
    PORT: 'Port',
    USE_CLIPBOARD: 'Use clipboard? (y/n)',
    USE_SERVER: 'Use server? (y/n)',
    NTFY_HOST: 'Notification server host (ntfy.sh) otherwise',
    NTFY_TOPIC_NAME: 'Notification server topic name (if none is provided ntfy is disabled)',
}

env  = {}
for key, question of keys
    if process.env[key]?
        console.log "Skipping #{key}"
    else
       await prompt question + ': ', (data) ->
            env[key] = data

fs.writeFileSync path.join(__dirname, '..', '.env'),
    (key + '=' + value for key, value of env).join('\n')


console.log 'Wrote .env file'
process.exit 0