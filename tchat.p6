unit module ChatServer ;
use Cro ;
use Cro::TCP ;
our $chat = Supplier.new() ;
our %variables = {name => "joseph", x => 3, y => 5} ;
our $lock-variables = Lock.new() ;
sub message(Str $string) {
  Cro::TCP::Message.new(data => $string.encode('utf-8')) ;
}
sub fromMessage($message) {
  $message.data().decode('utf-8') ;
}
sub msgMap($message, &code) {
  message(&code(fromMessage($message))) ;
}

sub interpolate(Str $string) {
   #S:g/\[(\w+)\]/{if %v{$0} {%v{$0};} else {"undefined";}}/ given "hello [name] and x is [x] now for [for]"
   $lock-variables.protect: {
   S:g/\[(\w+)\]/{if %variables{$0} {%variables{$0};} else {"undefined";}}/ given $string
   }
}

class Chat does Cro::Transform {
    method consumes() { Cro::TCP::Message }
    method produces() { Cro::TCP::Message }
    method transformer(Supply $source) {
        my $output = $chat.Supply ;
        my $name ;
        my $prompt = "Please, enter your name:\r\n" ;
        my $answer = supply {
            emit(message("Welcome to Perl Chat!\r\n"));
            emit(message($prompt));
            whenever $source -> $message {
                if $name {
                  say "message: " ~ $message.data().decode('utf-8') ;
                  $chat.emit(msgMap($message,-> $string {"$name: {interpolate($string)}";})) ;
                } else {
                  my $string = chomp(fromMessage($message)) ;
                  if $string !~~ /\w+/ {emit(message($prompt));} else {$name = $string ;}
                }
            }
            whenever $output -> $message {if $name { emit $message ; } else { ... }}
          }
        return $answer ;
    }
}
my Cro::Service $chat-server = Cro.compose(
    Cro::TCP::Listener.new(port => 8000),
    Chat
);
$chat-server.start();
react whenever signal(SIGINT) {
    $chat-server.stop;
    exit;
}
