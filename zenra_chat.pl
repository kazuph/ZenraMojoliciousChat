#!/usr/bin/env perl
package Zenra::Model;
use WebService::YahooJapan::WebMA;
use utf8;
use Data::Dumper qw/Dumper/;

$WebService::YahooJapan::WebMA::APIBase =
  'http://jlp.yahooapis.jp/MAService/V1/parse';

sub new {
    bless { yahoo_ma =>
          WebService::YahooJapan::WebMA->new( appid => '[YOUR_APP_KEY]', ), },
      shift;
}

sub zenrize {
    my ( $self, $sentence ) = @_;
    return unless $sentence;
    my $api       = $self->{yahoo_ma};
    my $result    = $api->parse( sentence => $sentence ) or return;
    my $ma_result = $result->{ma_result};

    my $result_text = '';
    for my $word ( @{ $ma_result->{word_list} } ) {
        $result_text .= "全裸で" if ( $word->{pos} eq '動詞' );
        $result_text .= $word->{surface};
    }
    return $result_text;
}

package main;
use utf8;
use Mojolicious::Lite;
use DateTime;
use Mojo::JSON;
use Encode qw/from_to decode_utf8 encode_utf8/;
use Data::Dumper qw/Dumper/;
use Encode;


app->helper(
    model => sub {
        Zenra::Model->new;
    }
);

get '/' => sub {
    my $self = shift;
#    return $self->render(j => $j, f => $f);
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

            # ここで全裸挿入
            $message = $self->app->model->zenrize(decode_utf8($message));

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

#   $self->finished(
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
  var url = 'ws://colinux:3000/echo';
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
<h1>Mojolicious + WebSocket + Zenra!!</h1>

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
