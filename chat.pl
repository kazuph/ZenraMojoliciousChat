#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite;
use DateTime;
use Mojo::JSON;
use Encode qw/from_to decode_utf8 encode_utf8/;
use Data::Dumper qw/Dumper/;
use Encode;

get '/' => sub {
    my $self = shift;
} => 'index';

my $clients = {};
websocket '/echo' => sub {
    my $self = shift;

    # デフォルトだとタイムアウトが15秒なのを300秒に修正
    Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

    app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    app->log->debug("id:".$id);
    $clients->{$id} = $self->tx;

#    $self->receive_message(
    $self->on(message => sub {
            my ($self, $msg) = @_;

            my ($name,$message) = split(/\t/,$msg);
            $self->app->log->debug('name: ', $name, 'message: ', $message);
            unless($name){
                $name = '名無し';
            }

            my $json = Mojo::JSON->new;
            my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');

            for (keys %$clients) {
                $clients->{$_}->send(
                    decode_utf8($json->encode({
                        hms  => $dt->hms,
                        name => $name,
                        text => $message,
                    }))
                );
            }
        }
    );

    $self->on(finish => sub {
            app->log->debug('Client disconnected');
            delete $clients->{$id};
        }
    );
};

app->start;

__DATA__
@@ index.html.ep
% layout 'main';
%= javascript begin
jQuery(function($) {
  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };
  var ws;
  var url = 'ws://localhost:3000/echo';
  if(typeof WebSocket != 'undefined'){
    ws = new WebSocket(url);
  }else if(typeof MozWebSocket != 'undefined'){
    ws = new MozWebSocket(url);
  }else{
    alert('WebSocket非対応です');
    return false;
  }
  ws.onopen = function () {
    log('Connection opened');
  };
  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log('[' + res.hms + '] (' + res.name + ') ' + res.text);
  };

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#name').val() + "\t" + $('#msg').val());
        $('#msg').val('');
    }
  });
    });
% end
<h1>Mojolicious + WebSocket</h1>

<p>name<input type="text" id="name" />msg<input type="text" id="msg" /></p>
<textarea id="log" readonly></textarea>
<div>
</div>

@@ layouts/main.html.ep
<html>
  <head>
    <meta charset="<%= app->renderer->encoding %>">
    <title>WebSocket Client</title>
    %= javascript 'https://ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js'
    <style type="text/css">
      textarea {
          width: 40em;
          height:10em;
      }
    </style>
  </head>
  <body><%= content %></body>
</html>
