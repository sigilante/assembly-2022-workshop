  ::  flappy.hoon
::::  Maintains leaderboard for Flappy Bird on Mars.
::
::    Scry endpoints:
::
::    x  /score           @ud
::    x  /hiscore         @ud
::    x  /score/[fren]    @ud
::
/-  *flappy, pals
/+  default-agent               :: agent arm defaults
/+  dbug                        :: debug wrapper for agent
/+  schooner                    :: HTTP request handling
/+  server                      :: HTTP request processing
/+  verb                        :: support verbose output for agent
/*  flappyui  %html  /app/flappy/index/html
|%
+$  versioned-state
  $%  state-zero
  ==
+$  state-zero  $:
      %zero
      =score
      hiscore=score
      =scores
    ==
+$  card  card:agent:gall
--
%-  agent:dbug
=|  state-zero
=*  state  -
%+  verb  |
^-  agent:gall
|_  bol=bowl:gall
+*  this     .
    default  ~(. (default-agent this %.n) bol)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  "%flappy initialized successfully."
  :_  this
  :~  [%pass /newpals %agent [our.bol %pals] %watch /targets]
      [%pass /eyre %arvo %e %connect [~ /apps/flappy] %flappy]
  ==
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-state)
  ?-  -.old
    %zero  `this(state old)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  =(our src):bol
  |^
  ?+    mark  (on-poke:default mark vase)
    ::
      %flappy-action
    =/  axn  !<(action vase)
    ?>  =(-.axn %gain)
    ?.  (gth score.axn hiscore)
      `this(score score.axn)
    :_  this(score score.axn, hiscore score.axn, scores (~(put by scores) our.bol score.axn))
    :~  [%give %fact ~[/flappy] %flappy-update !>(`update`lord+[score=score.axn fren=our.bol])]
    ==
    ::
      %handle-http-request
    (handle-http !<([@ta =inbound-request:eyre] vase))
  ==
  ::
  ++  handle-http
    |=  [eyre-id=@ta =inbound-request:eyre]
    ^-  (quip card _this)
    =/  ,request-line:server
      (parse-request-line:server url.request.inbound-request)
    =+  send=(cury response:schooner eyre-id)
    ?.  authenticated.inbound-request
      :_  this
      %-  send
      [302 ~ [%login-redirect './apps/flappy']]
    ::
    ?+    method.request.inbound-request
      [(send [405 ~ [%stock ~]]) this]
      ::
        %'POST'
      ?~  body.request.inbound-request
        [(send [405 ~ [%stock ~]]) this]
      =/  json  (de-json:html q.u.body.request.inbound-request)
      =/  axn  `action`(dejs-action +.json)
      (on-poke %flappy-action !>(axn))
      ::
        %'GET'
      ?+  site  :_  this
                %-  send
                :+  404
                  ~
                [%plain "404 - Not Found"]
          [%apps %flappy ~]
        :_  this
        %-  send
        :+  200
          ~
        [%html flappyui]
        ::
          [%apps %flappy %whoami ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %p our.bol)]
        ::
          [%apps %flappy %score ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud score)]
        ::
          [%apps %flappy %hiscore ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud hiscore)]
        ::
          [%apps %flappy %frens ~]
        :_  this
        %-  send
        :+  200
          ~
        [%json (enjs-scores scores)]
      ==
    ==
  ++  dejs-action
    =,  dejs:format
    |=  jon=json
    ^-  action
    %.  jon
    %-  of
    :~  [%gain (ot ~[score+ni])]
    ==
  ++  enjs-scores
    =,  enjs:format
    |=  =^scores
    ^-  json
    :-  %a
    :*
    %+  turn  ~(tap by scores)
    |=  point=[@p @ud]
    %-  pairs
    :~  ['fren' s+(scot %p -.point)]
        ['score' (numb +.point)]
    ==  ==
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:default path)
      [%http-response *]
    ?:  =(our src):bol
      `this
    (on-watch:default path)
  ::
      [%flappy ~]
    ~&  >  "on-watch:  {<src.bol>}"
    :_  this(scores (~(put by scores) src.bol 0))
    :~  [%give %fact ~[/flappy] %flappy-update !>(`update`lord+[(~(gut by scores) our.bol 0) our.bol])]
        [%pass /flappy %agent [src.bol %flappy] %watch /flappy]
    ==
  ==
::
++  on-leave  on-leave:default
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?>  =(our src):bol
  ?+  path  [~ ~]
    [%x %score ~]          ``noun+!>(score)
    [%x %hiscore ~]        ``noun+!>(hiscore)
    [%x %score fren ~]     ``noun+!>((~(get by scores) (slav %p +>-.path)))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire  (on-agent:default wire sign)
      [%flappy ~]
    ?+    -.sign  (on-agent:default wire sign)
      ::
        %fact
      ?+    p.cage.sign  (on-agent:default wire sign)
          %flappy-update
        =/  upd  !<(update q.cage.sign)
        ?>  =(-.upd %lord)
        ~&  >  "%flappy:  new score {<score.upd>} from {<fren.upd>}, current score {<(~(got by scores) fren.upd)>}"
        ?:  (gth (~(got by scores) fren.upd) score.upd)
          `this
        ~&  >  "%flappy:  new high score {<score.upd>} from {<fren.upd>}"
        `this(scores (~(put by scores) fren.upd score.upd))
      ==
      ::
        %kick
      :_  this
      :~  [%pass /flappy %agent [src.bol %flappy] %watch /flappy]
      ==
      ::
        %watch-ack
      ?~  p.sign
        ((slog '%flappy: Subscribe succeeded!' ~) `this)
      ((slog '%flappy: Subscribe failed!' ~) `this)
    ==
    ::
      [%newpals ~]
    ?+    -.sign  (on-agent:default wire sign)
        %fact
      ?+    p.cage.sign  (on-agent:default wire sign)
          %pals-effect
        =/  fx  !<(effect:pals q.cage.sign)
        ?+    -.fx  (on-agent:default wire sign)
            %meet
          :_  this(scores (~(put by scores) +.fx 0))
          :~  [%pass /flappy %agent [+.fx %flappy] %watch /flappy]
          ==
            %part
          :_  this(scores (~(del by scores) +.fx))
          :~  [%pass /flappy %agent [+.fx %flappy] %leave ~]
          ==
        ==
      ==  ==
  ==
::
++  on-arvo
|=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?.  ?=([%eyre %bound *] sign-arvo)
    (on-arvo:default [wire sign-arvo])
  ?:  accepted.sign-arvo
    %-  (slog leaf+"/apps/flappy bound successfully!" ~)
    `this
  %-  (slog leaf+"Binding /apps/flappy failed!" ~)
  `this
::
++  on-fail   on-fail:default
--
