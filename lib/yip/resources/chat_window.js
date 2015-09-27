(function() {
  var close = document.getElementsByClassName("chat-window-close")[0];

  close.addEventListener("click", function(event) {
    event.preventDefault();
    var data = JSON.stringify({ ns: "ctrl", payload: { op: "close" } });
    parent.postMessage(data, "*");
  });

  // parent.addEventListener('message', function(event) {
  //   var data = event.data && JSON.parse(event.data);

  //   if (data.ns == "ctrl") {
  //     var payload = data.payload || {};
  //   }
  // });

  var Chatbox = React.createClass({
    getInitialState: function() {
      return {
        data: Immutable.Map({ messages: Immutable.List() })
      };
    },
    handleTyperKeyup: function(event) {
      var isSubmit = event.which == 13 && !event.shiftKey;

      if (isSubmit) {
        event.preventDefault();
        console.log('typer submit');

        var message = Immutable.Map({ body: event.target.value.replace(/\n+$/g, "") });

        event.target.value = "";

        var data = JSON.stringify({ns: "ws", payload: message.get("body") });
        parent.postMessage(data, "*");

        this.setState(function(prev) {
          var data = prev.data;

          return {
            data: data.update('messages', function(messages) {
              return messages.push(message);
            })
          }
        });
      }
    },
    componentDidMount: function() {
      var that = this;

      addEventListener('message', function(event) {
        var data = event.data && JSON.parse(event.data);

        if (data.ns == "ctrl") {
          if (data.payload == "focus") {
            that.refs.typer.getDOMNode().focus();
          }
        }
      });
    },
    render: function() {
      var msgs = this.state.data.get('messages');
      var messageEls = Immutable.List();
      for (var idx = 0; idx < msgs.size; idx++) {
        var msg = msgs.get(idx);
        var messageEl = React.createElement('div', {}, msg.get('body'));
        messageEls = messageEls.push(messageEl);
      }

      var messages = React.createElement.apply(this, ['div', {}].concat(messageEls.toArray()));

      var typer = React.createElement('textarea', { ref: 'typer', className: 'chatbox-typer', onKeyUp: this.handleTyperKeyup });

      return (
        React.createElement('div', {}, messages, typer)
      );
    }
  });

  React.render(
    React.createElement(Chatbox),
    document.getElementById('chatbox-react-root')
  );
})();
