// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

let channel = socket.channel("Ricotta", {});
let list    = $('#message-list');
let message = $('#message');
let name    = $('#name');

message.on('keypress', event => {
  if (event.keyCode == 13) {
    channel.push('new_message', { name: name.val(), message: message.val() });
    message.val('');
  }
});

channel.on('new_message', payload => {
  list.append(`<b>${payload.name || 'Anonymous'}:</b> ${payload.message}<br>`);
  list.prop({scrollTop: list.prop("scrollHeight")});
});

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:
// let channel = socket.channel("room:42", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
