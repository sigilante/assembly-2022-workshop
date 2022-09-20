#   `%flap`
##  [Assembly 2022 Miami](https://assembly.urbit.org/) Workshop · ~2022.9.23

_Flappy Bird_ is an "insanely irritating, difficult and frustrating game which combines a super-steep difficulty curve with bad, boring graphics and jerky movement."  We are going to implement `%flap`, a _Flappy Bird_ leaderboard using `%pals` and an off-the-shelf FOSS JavaScript game.

This workshop assumes that you have completed some version of Hoon School and App School, whether the [live courses](https://developers.urbit.org/courses) or the [written docs](https://developers.urbit.org/guides/core/hoon-school/A-intro).

We are going to make the minimal number of changes necessary to implement the task.  We need to make the following components:

1. Build front end.  The FOSS app _simpliciter_ satisfies this to start.
2. Build data model.  We need to build the Gall agent.
3. Connect the game to the backend.  We need to make some few modifications to the front end.
4. Make friends talk to each other.  We need to hook up `%pals`.

We need to arrange a few pieces to begin:

1. Set up a development ship which can talk to the network.  This means a comet or a moon to start so we can easily install things.  Later on we'll move to a pair of fake ships to finalize things.
2. On that ship, `|install ~paldev %pals`.  Optionally, download ~palfun-foslup's [Suite repo](https://github.com/Fang-/suite) in case you need to refer to `%pals`-related code.
3. Download the [Flappy Bird repo](https://github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/).
4. Friend your neighbor's development ship so you'll be able to see each other later.
5. Set up a working directory thus.  Just `mkdir` or `touch` to make empty files where needed.

    ```
    ├── Original-Flappy-bird-JavaScript/
    ├── suite/
    ├── src/
    │   ├── app/
    │   │   └── flappy/
    │   ├── mar/
    │   │   └── flappy/
    │   ├── sur/
    │   ├── desk.bill
    │   ├── desk.docket-0
    │   └── sys.kelvin
    └── comet/
    ```

6. In the development ship, create a new clean desk:

    ```hoon
    |mount %base
    |mount %garden
    |merge %flappy our %base
    |mount %flap
    ```

    ```sh
    rm -rf comet/flap/*
    echo "~[%flap]" > comet/flap/desk.bill
    echo "[%zuse 418]" > comet/flap/sys.kelvin
    ```

7. At this point, we need to take stock of what kind of file marks we need available.  `kelvin`, `docket-0`, and so forth.  Also `js`, `png`.  There is no `wav` so we'll handle that differently.

    ```sh
    cp -r comet/base/lib comet/flap
    cp -r comet/base/sur comet/flap
    cp -r comet/base/mar comet/flap
    yes | cp -r comet/garden/lib comet/flap
    yes | cp -r comet/garden/sur comet/flap
    yes | cp -r comet/garden/mar comet/flap
    wget https://raw.githubusercontent.com/sigilante/assembly-2022-workshop/master/src/lib/schooner.hoon
    cp schooner.hoon comet/flap/lib
    ```

    and make some modest edits to `desk.docket-0`, e.g.:
    
    ```hoon
    :~
      title+'Flappy Bird'
      info+'An insanely irritating, difficult and frustrating game which combines a super-steep difficulty curve with bad, boring graphics and jerky movement.'
      color+0xea.c124
      version+[0 0 1]
      website+'https://urbit.org'
      license+'MIT'
      base+'flap'
      site+/apps/flap
    ==
    ```

    ```hoon
    |commit %flap
    ```

##  Front End

First, make a directory for the game content and copy it in.

```sh
mkdir comet/flap/app/flap
cp -r Original-Flappy-bird-JavaScript/* comet/flap/app/flap
```

Now we have to deal with the `wav` file mark.  Let's copy over `/mar/png.hoon` and modify it:

```hoon
|_  dat=@                                                                                             
++  grow
  |%
  ++  mime  [/audio/wav (as-octs:mimes:html dat)]
  --
++  grab
  |%
  ++  mime  |=([p=mite q=octs] q.q)
  ++  noun  @
  --
++  grad  %mime
--
```

The above `index.html` file will work now if you open it in the browser directly, but it doesn't have any connection to Urbit yet.  Clay doesn't know where to build everything and hook it up, so at a minimum we have to load and display the front-end using `/app/flap.hoon`.


##  Urbit Back-End

For the Urbit back-end, we need a data model.  We aren't interested in calculating the gameplay mechanics, only in the scores.  So we expect to be able to track our state including:

- our current score (last game) (`score`)
- our all-time high score (`hiscore`)
- the all-time high score of our `%pals` (`scores`)

We don't need to actively track friends _except_ that they will have entries in `scores`, even if zero.

**`/sur/flap.hoon`**:

The basic structure file defines friendship, which it will derive from `%pals`, and scores.  Scores are simple, so they're just a matter of a single `@ud` number.

We `%gain` a `score` at the end of each game by an `%action`, and track our own `hiscore`.  We `%lord` a high score over others (or they over us) by sending and receiving `%update`s.  (So `%action`s are vertical between client and server, while `%update`s are horizontal between servers.)

```hoon
|%
+$  fren    @p
+$  score   @ud
+$  scores  (map fren score)
::
+$  action
  $%  [%gain =score]
  ==
::
+$  update
  $%  [%lord =score =fren]
  ==
--
```

**`/mar/flap/action.hoon`**:

Given an action to `%gain` a score as a JSON, we process it in the mark and yield it as an `%action`.

```hoon
/-  flap
|_  =action:flap
++  grab
  |%
  ++  noun  action:flap
  ++  json
    =,  dejs:format
    |=  jon=json
    ^-  action
    %.  jon
    %-  of
    :~  [%gain (ot ~[score+ni])]
    ==
  --
++  grow
  |%
  ++  noun  action
  --
++  grad  %noun
--
```

E.g. this should process:

```hoon
(de-json:html '{"newscore":15}')
(dejs-action (need (de-json:html '{"gain":{"score":15}}')))
```

**`/mar/flap/update.hoon`**:

Given an action to `%lord` a score as a JSON, we can process it in place and yield it as a `%flappy-update`.

```hoon
/-  flap
|_  =update:flap
++  grab
  |%
  ++  noun  update:flap
  ++  json
    =,  dejs:format
    |=  jon=json
    ^-  update:flap
    %.  jon
    %-  of
    :~  [%lord (ot ~[score+ni fren+(se %p)])]
    ==
  --
++  grow
  |%
  ++  noun  update
  --
++  grad  %noun
--
```

**`/app/flap.hoon`**:

The main app implements the logic for exposing and tracking data.

```hoon
  ::  flap.hoon
::::  Maintains leaderboard for Flappy Bird on Mars.
::
/-  *flap
/+  default-agent               :: agent arm defaults
/+  dbug                        :: debug wrapper for agent
/+  schooner                    :: HTTP request handling
/+  server                      :: HTTP request processing
/+  verb                        :: support verbose output for agent
/*  flapui  %html  /app/flap/index/html
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
  ~&  >  "%flap initialized successfully."
  :_  this
  :~  [%pass /eyre %arvo %e %connect [~ /apps/flap] %flap]
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
      %flap-action
    =/  axn  !<(action vase)
    ?>  =(-.axn %gain)
    ?.  (gth score.axn hiscore)
      `this(score score.axn)
    :_  this(score score.axn, hiscore score.axn, scores (~(put by scores) our.bol score.axn))
    :~  [%give %fact ~[/flap] %flap-update !>(`update`lord+[score=score.axn fren=our.bol])]
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
      [302 ~ [%login-redirect './apps/flap']]
    ::
    ?+    method.request.inbound-request
      [(send [405 ~ [%stock ~]]) this]
      ::
        %'POST'
      ?~  body.request.inbound-request
        [(send [405 ~ [%stock ~]]) this]
      =/  json  (de-json:html q.u.body.request.inbound-request)
      =/  axn  `action`(dejs-action +.json)
      (on-poke %flap-action !>(axn))
      ::
        %'GET'
      ?+  site  :_  this
                %-  send
                :+  404
                  ~
                [%plain "404 - Not Found"]
          [%apps %flap ~]
        :_  this
        %-  send
        :+  200
          ~
        [%html flapui]
        ::
          [%apps %flap %whoami ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %p our.bol)]
        ::
          [%apps %flap %score ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud score)]
        ::
          [%apps %flap %hiscore ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud hiscore)]
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
  ==
::
++  on-leave  on-leave:default
::
++  on-peek  on-peek:default
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire  (on-agent:default wire sign)
      [%flap ~]
    ?+    -.sign  (on-agent:default wire sign)
      ::
        %fact
      ?+    p.cage.sign  (on-agent:default wire sign)
          %flap-update
        =/  newupdate  !<(update q.cage.sign)
        ?-    -.newupdate
            %lord
          !!
        ==
      ==
      ::
        %kick
      :_  this
      :~  [%pass /flap %agent [src.bol %flap] %watch /updates/out]
      ==
      ::
        %watch-ack
      ?~  p.sign
        ((slog '%flap: Subscribe succeeded!' ~) `this)
      ((slog '%flap: Subscribe failed!' ~) `this)
    ==
  ==
::
++  on-arvo
|=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?.  ?=([%eyre %bound *] sign-arvo)
    (on-arvo:default [wire sign-arvo])
  ?:  accepted.sign-arvo
    %-  (slog leaf+"/apps/flap bound successfully!" ~)
    `this
  %-  (slog leaf+"Binding /apps/flap failed!" ~)
  `this
::
++  on-fail   on-fail:default
--
```

Now when we navigate to `localhost:8080/apps/flap`, what do we see?  An empty box.  There are two things that go wrong at this point:  locating `game.js` at the right path, and dealing with CORS issues.  The quickest solution for our case now is to simply copy `game.js` into the `script` tag.

The above back-end also doesn't yet know about `%pals`, so `scores` as a `(map fren score)` is only a stub for planned communication now.

First, we try just replacing the `game.js` in the `script` tag.  The next problem we encounter is that the components have trouble being locally hosted.  So for now we can just hot-load them from the Internet directly.  This yields:

**`/app/flap/index.html`**:

This is verbatim the `index.html` file supplied from the repo, except that the `game.js` content is included as a script to avoid CORS issues.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Original Flappy Bird -JavaScript</title>
    <link href="https://fonts.googleapis.com/css?family=Teko:700" rel="stylesheet">
    <style>        
        canvas{
            border: 1px solid #000;
            display: block;
            margin: 0 auto;
        }
    </style>
</head>
<body>
<canvas id="bird" width="320" height="480"></canvas>

<script type="module">

// SELECT CVS
const cvs = document.getElementById("bird");
const ctx = cvs.getContext("2d");

// GAME VARS AND CONSTS
let frames = 0;
const DEGREE = Math.PI/180;

// LOAD SPRITE IMAGE
const sprite = new Image();
sprite.src = "https://raw.githubusercontent.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/img/sprite.png";

// LOAD SOUNDS
const SCORE_S = new Audio();
SCORE_S.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_point.wav";

const FLAP = new Audio();
FLAP.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_flap.wav";

const HIT = new Audio();
HIT.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_hit.wav";

const SWOOSHING = new Audio();
SWOOSHING.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_swooshing.wav";

const DIE = new Audio();
DIE.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_die.wav";

// GAME STATE
const state = {
    current : 0,
    getReady : 0,
    game : 1,
    over : 2
}

// START BUTTON COORD
const startBtn = {
    x : 120,
    y : 263,
    w : 83,
    h : 29
}

// CONTROL THE GAME
cvs.addEventListener("click", function(evt){
    switch(state.current){
        case state.getReady:
            state.current = state.game;
            SWOOSHING.play();
            break;
        case state.game:
            if(bird.y - bird.radius <= 0) return;
            bird.flap();
            FLAP.play();
            break;
        case state.over:
            let rect = cvs.getBoundingClientRect();
            let clickX = evt.clientX - rect.left;
            let clickY = evt.clientY - rect.top;
            
            // CHECK IF WE CLICK ON THE START BUTTON
            if(clickX >= startBtn.x && clickX <= startBtn.x + startBtn.w && clickY >= startBtn.y && clickY <= startBtn.y + startBtn.h){
                pipes.reset();
                bird.speedReset();
                score.reset();
                state.current = state.getReady;
            }
            break;
    }
});


// BACKGROUND
const bg = {
    sX : 0,
    sY : 0,
    w : 275,
    h : 226,
    x : 0,
    y : cvs.height - 226,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    }
    
}

// FOREGROUND
const fg = {
    sX: 276,
    sY: 0,
    w: 224,
    h: 112,
    x: 0,
    y: cvs.height - 112,
    
    dx : 2,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    },
    
    update: function(){
        if(state.current == state.game){
            this.x = (this.x - this.dx)%(this.w/2);
        }
    }
}

// BIRD
const bird = {
    animation : [
        {sX: 276, sY : 112},
        {sX: 276, sY : 139},
        {sX: 276, sY : 164},
        {sX: 276, sY : 139}
    ],
    x : 50,
    y : 150,
    w : 34,
    h : 26,
    
    radius : 12,
    
    frame : 0,
    
    gravity : 0.15,
    jump : 2.6,
    speed : 0,
    rotation : 0,
    
    draw : function(){
        let bird = this.animation[this.frame];
        
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.drawImage(sprite, bird.sX, bird.sY, this.w, this.h,- this.w/2, - this.h/2, this.w, this.h);
        
        ctx.restore();
    },
    
    flap : function(){
        this.speed = - this.jump;
    },
    
    update: function(){
        // IF THE GAME STATE IS GET READY STATE, THE BIRD MUST FLAP SLOWLY
        this.period = state.current == state.getReady ? 10 : 5;
        // WE INCREMENT THE FRAME BY 1, EACH PERIOD
        this.frame += frames%this.period == 0 ? 1 : 0;
        // FRAME GOES FROM 0 To 4, THEN AGAIN TO 0
        this.frame = this.frame%this.animation.length;
        
        if(state.current == state.getReady){
            this.y = 150; // RESET POSITION OF THE BIRD AFTER GAME OVER
            this.rotation = 0 * DEGREE;
        }else{
            this.speed += this.gravity;
            this.y += this.speed;
            
            if(this.y + this.h/2 >= cvs.height - fg.h){
                this.y = cvs.height - fg.h - this.h/2;
                if(state.current == state.game){
                    state.current = state.over;
                    DIE.play();
                }
            }
            
            // IF THE SPEED IS GREATER THAN THE JUMP MEANS THE BIRD IS FALLING DOWN
            if(this.speed >= this.jump){
                this.rotation = 90 * DEGREE;
                this.frame = 1;
            }else{
                this.rotation = -25 * DEGREE;
            }
        }
        
    },
    speedReset : function(){
        this.speed = 0;
    }
}

// GET READY MESSAGE
const getReady = {
    sX : 0,
    sY : 228,
    w : 173,
    h : 152,
    x : cvs.width/2 - 173/2,
    y : 80,
    
    draw: function(){
        if(state.current == state.getReady){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// GAME OVER MESSAGE
const gameOver = {
    sX : 175,
    sY : 228,
    w : 225,
    h : 202,
    x : cvs.width/2 - 225/2,
    y : 90,
    
    draw: function(){
        if(state.current == state.over){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// PIPES
const pipes = {
    position : [],
    
    top : {
        sX : 553,
        sY : 0
    },
    bottom:{
        sX : 502,
        sY : 0
    },
    
    w : 53,
    h : 400,
    gap : 85,
    maxYPos : -150,
    dx : 2,
    
    draw : function(){
        for(let i  = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let topYPos = p.y;
            let bottomYPos = p.y + this.h + this.gap;
            
            // top pipe
            ctx.drawImage(sprite, this.top.sX, this.top.sY, this.w, this.h, p.x, topYPos, this.w, this.h);  
            
            // bottom pipe
            ctx.drawImage(sprite, this.bottom.sX, this.bottom.sY, this.w, this.h, p.x, bottomYPos, this.w, this.h);  
        }
    },
    
    update: function(){
        if(state.current !== state.game) return;
        
        if(frames%100 == 0){
            this.position.push({
                x : cvs.width,
                y : this.maxYPos * ( Math.random() + 1)
            });
        }
        for(let i = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let bottomPipeYPos = p.y + this.h + this.gap;
            
            // COLLISION DETECTION
            // TOP PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > p.y && bird.y - bird.radius < p.y + this.h){
                state.current = state.over;
                HIT.play();
            }
            // BOTTOM PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > bottomPipeYPos && bird.y - bird.radius < bottomPipeYPos + this.h){
                state.current = state.over;
                HIT.play();
            }
            
            // MOVE THE PIPES TO THE LEFT
            p.x -= this.dx;
            
            // if the pipes go beyond canvas, we delete them from the array
            if(p.x + this.w <= 0){
                this.position.shift();
                score.value += 1;
                SCORE_S.play();
                score.best = Math.max(score.value, score.best);
                localStorage.setItem("best", score.best);
            }
        }
    },
    
    reset : function(){
        this.position = [];
    }
    
}

// SCORE
const score= {
    best : parseInt(localStorage.getItem("best")) || 0,
    value : 0,
    
    draw : function(){
        ctx.fillStyle = "#FFF";
        ctx.strokeStyle = "#000";
        
        if(state.current == state.game){
            ctx.lineWidth = 2;
            ctx.font = "35px Teko";
            ctx.fillText(this.value, cvs.width/2, 50);
            ctx.strokeText(this.value, cvs.width/2, 50);
            
        }else if(state.current == state.over){
            // SCORE VALUE
            ctx.font = "25px Teko";
            ctx.fillText(this.value, 225, 186);
            ctx.strokeText(this.value, 225, 186);
            // BEST SCORE
            ctx.fillText(this.best, 225, 228);
            ctx.strokeText(this.best, 225, 228);
        }
    },
    
    reset : function(){
        this.value = 0;
    }
}

// DRAW
function draw(){
    ctx.fillStyle = "#70c5ce";
    ctx.fillRect(0, 0, cvs.width, cvs.height);
    
    bg.draw();
    pipes.draw();
    fg.draw();
    bird.draw();
    getReady.draw();
    gameOver.draw();
    score.draw();
}

// UPDATE
function update(){
    bird.update();
    fg.update();
    pipes.update();
}

// LOOP
function loop(){
    update();
    draw();
    frames++;
    
    requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>
```

This will run in our browser correctly.  Urbit knows where it is and how to serve it.


##  Connecting the Pieces

Flappy Bird in HTML+JS needs Urbit affordances so it knows how to talk to the app backend.  The cool thing is that with the foregoing setup, the Urbit integration we built should \*just work*.

**`/app/flappy/index/html`**:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Martian Flappy Bird -JavaScript</title>
    <link href="https://fonts.googleapis.com/css?family=Teko:700" rel="stylesheet">
    <style>        
        canvas{
            border: 1px solid #000;
            display: block;
            margin: 0 auto;
        }
    </style>
</head>
<body>
<canvas id="bird" width="320" height="480"></canvas>

<p>
<span id="ship"></span>:  <span id="score"></span>/<span id="hiscore"></span>
</p>

<script type="module">

// URBIT STATE
async function getmyship() {
        const response = await fetch('/apps/flap/whoami');
        return response.text();
    }
var myshipname = await getmyship();
document.getElementById("ship").innerHTML = myshipname;

async function gethiscore() {
        const response = await fetch('/apps/flap/hiscore');
        return response.text();
    }
var myhiscore = await gethiscore();

async function getscore() {
        const response = await fetch('/apps/flap/score');
        return response.text();
    }
var myscore = await getscore();

document.getElementById("hiscore").innerHTML = myhiscore;
document.getElementById("score").innerHTML = myscore;

//  Send score to Gall agent
function sendscore(score) {
    fetch('/apps/flap', {
        method: 'POST',
        body: JSON.stringify({'gain': {'score': score.value}})
    })
}


// SELECT CVS
const cvs = document.getElementById("bird");
const ctx = cvs.getContext("2d");

// GAME VARS AND CONSTS
let frames = 0;
const DEGREE = Math.PI/180;

// LOAD SPRITE IMAGE
const sprite = new Image();
sprite.src = "https://raw.githubusercontent.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/img/sprite.png";

// LOAD SOUNDS
const SCORE_S = new Audio();
SCORE_S.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_point.wav";

const FLAP = new Audio();
FLAP.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_flap.wav";

const HIT = new Audio();
HIT.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_hit.wav";

const SWOOSHING = new Audio();
SWOOSHING.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_swooshing.wav";

const DIE = new Audio();
DIE.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_die.wav";

// GAME STATE
const state = {
    current : 0,
    getReady : 0,
    game : 1,
    over : 2
}

// START BUTTON COORD
const startBtn = {
    x : 120,
    y : 263,
    w : 83,
    h : 29
}

// CONTROL THE GAME
cvs.addEventListener("click", function(evt){
    switch(state.current){
        case state.getReady:
            state.current = state.game;
            SWOOSHING.play();
            break;
        case state.game:
            if(bird.y - bird.radius <= 0) return;
            bird.flap();
            FLAP.play();
            break;
        case state.over:
            let rect = cvs.getBoundingClientRect();
            let clickX = evt.clientX - rect.left;
            let clickY = evt.clientY - rect.top;
            
            // CHECK IF WE CLICK ON THE START BUTTON
            if(clickX >= startBtn.x && clickX <= startBtn.x + startBtn.w && clickY >= startBtn.y && clickY <= startBtn.y + startBtn.h){
                pipes.reset();
                bird.speedReset();
                score.reset();
                state.current = state.getReady;
            }
            break;
    }
});


// BACKGROUND
const bg = {
    sX : 0,
    sY : 0,
    w : 275,
    h : 226,
    x : 0,
    y : cvs.height - 226,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    }
    
}

// FOREGROUND
const fg = {
    sX: 276,
    sY: 0,
    w: 224,
    h: 112,
    x: 0,
    y: cvs.height - 112,
    
    dx : 2,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    },
    
    update: function(){
        if(state.current == state.game){
            this.x = (this.x - this.dx)%(this.w/2);
        }
    }
}

// BIRD
const bird = {
    animation : [
        {sX: 276, sY : 112},
        {sX: 276, sY : 139},
        {sX: 276, sY : 164},
        {sX: 276, sY : 139}
    ],
    x : 50,
    y : 150,
    w : 34,
    h : 26,
    
    radius : 12,
    
    frame : 0,
    
    gravity : 0.15,
    jump : 2.6,
    speed : 0,
    rotation : 0,
    
    draw : function(){
        let bird = this.animation[this.frame];
        
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.drawImage(sprite, bird.sX, bird.sY, this.w, this.h,- this.w/2, - this.h/2, this.w, this.h);
        
        ctx.restore();
    },
    
    flap : function(){
        this.speed = - this.jump;
    },
    
    update: function(){
        // IF THE GAME STATE IS GET READY STATE, THE BIRD MUST FLAP SLOWLY
        this.period = state.current == state.getReady ? 10 : 5;
        // WE INCREMENT THE FRAME BY 1, EACH PERIOD
        this.frame += frames%this.period == 0 ? 1 : 0;
        // FRAME GOES FROM 0 To 4, THEN AGAIN TO 0
        this.frame = this.frame%this.animation.length;
        
        if(state.current == state.getReady){
            this.y = 150; // RESET POSITION OF THE BIRD AFTER GAME OVER
            this.rotation = 0 * DEGREE;
        }else{
            this.speed += this.gravity;
            this.y += this.speed;
            
            if(this.y + this.h/2 >= cvs.height - fg.h){
                this.y = cvs.height - fg.h - this.h/2;
                if(state.current == state.game){
                    state.current = state.over;
                    sendscore(score);
                    document.getElementById("hiscore").innerHTML = myhiscore;
                    document.getElementById("score").innerHTML = myscore;
                    DIE.play();
                }
            }
            
            // IF THE SPEED IS GREATER THAN THE JUMP MEANS THE BIRD IS FALLING DOWN
            if(this.speed >= this.jump){
                this.rotation = 90 * DEGREE;
                this.frame = 1;
            }else{
                this.rotation = -25 * DEGREE;
            }
        }
        
    },
    speedReset : function(){
        this.speed = 0;
    }
}

// GET READY MESSAGE
const getReady = {
    sX : 0,
    sY : 228,
    w : 173,
    h : 152,
    x : cvs.width/2 - 173/2,
    y : 80,
    
    draw: function(){
        if(state.current == state.getReady){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// GAME OVER MESSAGE
const gameOver = {
    sX : 175,
    sY : 228,
    w : 225,
    h : 202,
    x : cvs.width/2 - 225/2,
    y : 90,
    
    draw: function(){
        if(state.current == state.over){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// PIPES
const pipes = {
    position : [],
    
    top : {
        sX : 553,
        sY : 0
    },
    bottom:{
        sX : 502,
        sY : 0
    },
    
    w : 53,
    h : 400,
    gap : 85,
    maxYPos : -150,
    dx : 2,
    
    draw : function(){
        for(let i  = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let topYPos = p.y;
            let bottomYPos = p.y + this.h + this.gap;
            
            // top pipe
            ctx.drawImage(sprite, this.top.sX, this.top.sY, this.w, this.h, p.x, topYPos, this.w, this.h);  
            
            // bottom pipe
            ctx.drawImage(sprite, this.bottom.sX, this.bottom.sY, this.w, this.h, p.x, bottomYPos, this.w, this.h);  
        }
    },
    
    update: function(){
        if(state.current !== state.game) return;
        
        if(frames%100 == 0){
            this.position.push({
                x : cvs.width,
                y : this.maxYPos * ( Math.random() + 1)
            });
        }
        for(let i = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let bottomPipeYPos = p.y + this.h + this.gap;
            
            // COLLISION DETECTION
            // TOP PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > p.y && bird.y - bird.radius < p.y + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                HIT.play();
            }
            // BOTTOM PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > bottomPipeYPos && bird.y - bird.radius < bottomPipeYPos + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                HIT.play();
            }
            
            // MOVE THE PIPES TO THE LEFT
            p.x -= this.dx;
            
            // if the pipes go beyond canvas, we delete them from the array
            if(p.x + this.w <= 0){
                this.position.shift();
                score.value += 1;
                SCORE_S.play();
                score.best = Math.max(score.value, score.best);
                localStorage.setItem("best", score.best);
            }
        }
    },
    
    reset : function(){
        this.position = [];
    }
    
}

// SCORE
const score= {
    best : parseInt(localStorage.getItem("best")) || gethiscore(),
    value : 0,
    
    draw : function(){
        ctx.fillStyle = "#FFF";
        ctx.strokeStyle = "#000";
        
        if(state.current == state.game){
            ctx.lineWidth = 2;
            ctx.font = "35px Teko";
            ctx.fillText(this.value, cvs.width/2, 50);
            ctx.strokeText(this.value, cvs.width/2, 50);
            
        }else if(state.current == state.over){
            // SCORE VALUE
            ctx.font = "25px Teko";
            ctx.fillText(this.value, 225, 186);
            ctx.strokeText(this.value, 225, 186);
            // BEST SCORE
            ctx.fillText(this.best, 225, 228);
            ctx.strokeText(this.best, 225, 228);
        }
    },
    
    reset : function(){
        this.value = 0;
    }
}

// DRAW
function draw(){
    ctx.fillStyle = "#70c5ce";
    ctx.fillRect(0, 0, cvs.width, cvs.height);
    
    bg.draw();
    pipes.draw();
    fg.draw();
    bird.draw();
    getReady.draw();
    gameOver.draw();
    score.draw();
}

// UPDATE
function update(){
    bird.update();
    fg.update();
    pipes.update();
}

// LOOP
function loop(){
    update();
    draw();
    frames++;
    
    requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>
```

If you `|commit` all of the above, you should have a working `%flappy` instance at `http://localhost:8080/apps/flappy`.  Use `:flappy +dbug` to check that the score is being communicated back.

At this point, you can check out the API endpoints listed in the code above:  `/apps/flap/whoami` and so forth.


##  Adding Friends with `%pals`

Next, let's integrate knowledge of other friends (and thus the ability to maintain a leaderboard of our friends).

```hoon
|commit %pals
```

```sh
cp -r comet/pals/mar/pals comet/flap/mar/
cp -r comet/pals/sur/pals.hoon comet/flap/sur/
```

```hoon
  ::  flap.hoon
::::  Maintains leaderboard for Flappy Bird on Mars.
::
/-  *flap, pals
/+  default-agent               :: agent arm defaults
/+  dbug                        :: debug wrapper for agent
/+  schooner                    :: HTTP request handling
/+  server                      :: HTTP request processing
/+  verb                        :: support verbose output for agent
/*  flapui  %html  /app/flap/index/html
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
  ~&  >  "%flap initialized successfully."
  :_  this
  :~  [%pass /newpals %agent [our.bol %pals] %watch /targets]
      [%pass /eyre %arvo %e %connect [~ /apps/flap] %flap]
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
      %flap-action
    =/  axn  !<(action vase)
    ?>  =(-.axn %gain)
    ?.  (gth score.axn hiscore)
      `this(score score.axn)
    :_  this(score score.axn, hiscore score.axn, scores (~(put by scores) our.bol score.axn))
    :~  [%give %fact ~[/flap] %flap-update !>(`update`lord+[score=score.axn fren=our.bol])]
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
      [302 ~ [%login-redirect './apps/flap']]
    ::
    ?+    method.request.inbound-request
      [(send [405 ~ [%stock ~]]) this]
      ::
        %'POST'
      ?~  body.request.inbound-request
        [(send [405 ~ [%stock ~]]) this]
      =/  json  (de-json:html q.u.body.request.inbound-request)
      =/  axn  `action`(dejs-action +.json)
      (on-poke %flap-action !>(axn))
      ::
        %'GET'
      ?+  site  :_  this
                %-  send
                :+  404
                  ~
                [%plain "404 - Not Found"]
          [%apps %flap ~]
        :_  this
        %-  send
        :+  200
          ~
        [%html flapui]
        ::
          [%apps %flap %whoami ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %p our.bol)]
        ::
          [%apps %flap %score ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud score)]
        ::
          [%apps %flap %hiscore ~]
        :_  this
        %-  send
        :+  200
          ~
        [%plain (scow %ud hiscore)]
        ::
          [%apps %flap %frens ~]
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
      [%flap ~]
    :_  this
    :~  [%give %fact ~[/flap] %flap-update !>(`update`lord+[(~(gut by scores) our.bol 0) our.bol])]
        [%pass /flap %agent [src.bol %flap] %watch /flap]
    ==
  ==
::
++  on-leave  on-leave:default
::
++  on-peek  on-peek:default
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire  (on-agent:default wire sign)
      [%flap ~]
    ?+    -.sign  (on-agent:default wire sign)
      ::
        %fact
      ?+    p.cage.sign  (on-agent:default wire sign)
          %flap-update
        =/  upd  !<(update q.cage.sign)
        ?>  =(-.upd %lord)
        ?:  (gth (~(got by scores) fren.upd) score.upd)
          `this
        ~&  >  "%flappy:  new high score {<score.upd>} from {<fren.upd>}"
        `this(scores (~(put by scores) fren.upd score.upd))
      ==
      ::
        %kick
      :_  this
      :~  [%pass /flap %agent [src.bol %flap] %watch /updates/out]
      ==
      ::
        %watch-ack
      ?~  p.sign
        ((slog '%flap: Subscribe succeeded!' ~) `this)
      ((slog '%flap: Subscribe failed!' ~) `this)
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
          :~  [%pass /flap %agent [+.fx %flap] %watch /flap]
          ==
            %part
          :_  this(scores (~(del by scores) +.fx))
          :~  [%pass /flap %agent [+.fx %flap] %leave ~]
          ==
        ==
      ==
    ==
  ==
::
++  on-arvo
|=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?.  ?=([%eyre %bound *] sign-arvo)
    (on-arvo:default [wire sign-arvo])
  ?:  accepted.sign-arvo
    %-  (slog leaf+"/apps/flap bound successfully!" ~)
    `this
  %-  (slog leaf+"Binding /apps/flap failed!" ~)
  `this
::
++  on-fail   on-fail:default
--
```

**`/app/flappy/index.html`**:

This only needs some display updating so we can see our friends, who are retrieved from `%pals` and stored with a bunted score if no score has been received yet.

We can make the critique that the JS client-side `score.best` and the Urbit server-side `hiscore` aren't actually connected at first, but in a subsequent run this will have the correct behavior.

We will receive and produce JSONs of the following form to populate the leaderboard on our display:

```json
[
 {"fren":"~zod", "score":100},
 {"fren":"~nec", "score":101},
 {"fren":"~bud", "score":102},
 {"fren":"~wec", "score":103}
]
```

We will add a table which will periodically update with the current pull of scores from friends.  Right now this is ugly and we will add some CSS styling at the end.

**`/app/flap/index.hoon`**:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Martian Flappy Bird -JavaScript</title>
    <link href="https://fonts.googleapis.com/css?family=Teko:700" rel="stylesheet">
    <style>        
        canvas{
            border: 1px solid #000;
            display: block;
            margin: 0 auto;
        }
    </style>
</head>
<body>
<canvas id="bird" width="320" height="480"></canvas>

<p>
<span id="ship"></span>:  <span id="score"></span>/<span id="hiscore"></span>
</p>

<p>
<div id="frens"></div>
</p>

<script type="module">

// URBIT STATE
async function getmyship() {
        const response = await fetch('/apps/flap/whoami');
        return response.text();
    }
var myshipname = await getmyship();
document.getElementById("ship").innerHTML = myshipname;

async function gethiscore() {
        const response = await fetch('/apps/flap/hiscore');
        return response.text();
    }
var myhiscore = await gethiscore();

document.getElementById("hiscore").innerHTML = myhiscore;

async function getscore() {
        const response = await fetch('/apps/flap/score');
        return response.text();
    }
var myscore = await getscore();
document.getElementById("score").innerHTML = myscore;

//  Send score to Gall agent
function sendscore(score) {
    fetch('/apps/flap', {
        method: 'POST',
        body: JSON.stringify({'gain': {'score': score.value}})
    })
}

//  Draw table of frens
async function getfrens() {
        const response = await fetch('/apps/flap/frens');
        return response.text();
    }
function drawtable(myfrens) {
    console.log(myfrens);
    var frens = JSON.parse(myfrens);

    var table = document.createElement("table");
    var titleRow = table.insertRow();
    var frenCell = titleRow.insertCell();
    frenCell.innerHTML = "Ship";
    var scoreCell = titleRow.insertCell();
    scoreCell.innerHTML = "Score";
    
    for (let key in frens) {
        var row = table.insertRow();
        var cell = row.insertCell();
        cell.classList += "ship";
        cell.innerHTML = frens[key]['fren'];
        cell = row.insertCell();
        cell.innerHTML = frens[key]['score'];
    }

    // Clear the old table
    const list = document.getElementById("frens");
    while (list.hasChildNodes()) {
        list.removeChild(list.firstChild);
    }
    // Add the new one
    document.getElementById("frens").appendChild(table);
}
var myfrens = await getfrens();
console.log(myfrens);
drawtable(myfrens);

// SELECT CVS
const cvs = document.getElementById("bird");
const ctx = cvs.getContext("2d");

// GAME VARS AND CONSTS
let frames = 0;
const DEGREE = Math.PI/180;

// LOAD SPRITE IMAGE
const sprite = new Image();
sprite.src = "https://raw.githubusercontent.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/img/sprite.png";

// LOAD SOUNDS
const SCORE_S = new Audio();
SCORE_S.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_point.wav";

const FLAP = new Audio();
FLAP.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_flap.wav";

const HIT = new Audio();
HIT.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_hit.wav";

const SWOOSHING = new Audio();
SWOOSHING.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_swooshing.wav";

const DIE = new Audio();
DIE.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_die.wav";

// GAME STATE
const state = {
    current : 0,
    getReady : 0,
    game : 1,
    over : 2
}

// START BUTTON COORD
const startBtn = {
    x : 120,
    y : 263,
    w : 83,
    h : 29
}

// CONTROL THE GAME
cvs.addEventListener("click", function(evt){
    switch(state.current){
        case state.getReady:
            state.current = state.game;
            SWOOSHING.play();
            break;
        case state.game:
            if(bird.y - bird.radius <= 0) return;
            bird.flap();
            FLAP.play();
            break;
        case state.over:
            let rect = cvs.getBoundingClientRect();
            let clickX = evt.clientX - rect.left;
            let clickY = evt.clientY - rect.top;
            
            // CHECK IF WE CLICK ON THE START BUTTON
            if(clickX >= startBtn.x && clickX <= startBtn.x + startBtn.w && clickY >= startBtn.y && clickY <= startBtn.y + startBtn.h){
                pipes.reset();
                bird.speedReset();
                score.reset();
                state.current = state.getReady;
            }
            break;
    }
});


// BACKGROUND
const bg = {
    sX : 0,
    sY : 0,
    w : 275,
    h : 226,
    x : 0,
    y : cvs.height - 226,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    }
    
}

// FOREGROUND
const fg = {
    sX: 276,
    sY: 0,
    w: 224,
    h: 112,
    x: 0,
    y: cvs.height - 112,
    
    dx : 2,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    },
    
    update: function(){
        if(state.current == state.game){
            this.x = (this.x - this.dx)%(this.w/2);
        }
    }
}

// BIRD
const bird = {
    animation : [
        {sX: 276, sY : 112},
        {sX: 276, sY : 139},
        {sX: 276, sY : 164},
        {sX: 276, sY : 139}
    ],
    x : 50,
    y : 150,
    w : 34,
    h : 26,
    
    radius : 12,
    
    frame : 0,
    
    gravity : 0.15,
    jump : 2.6,
    speed : 0,
    rotation : 0,
    
    draw : function(){
        let bird = this.animation[this.frame];
        
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.drawImage(sprite, bird.sX, bird.sY, this.w, this.h,- this.w/2, - this.h/2, this.w, this.h);
        
        ctx.restore();
    },
    
    flap : function(){
        this.speed = - this.jump;
    },
    
    update: function(){
        // IF THE GAME STATE IS GET READY STATE, THE BIRD MUST FLAP SLOWLY
        this.period = state.current == state.getReady ? 10 : 5;
        // WE INCREMENT THE FRAME BY 1, EACH PERIOD
        this.frame += frames%this.period == 0 ? 1 : 0;
        // FRAME GOES FROM 0 To 4, THEN AGAIN TO 0
        this.frame = this.frame%this.animation.length;
        
        if(state.current == state.getReady){
            this.y = 150; // RESET POSITION OF THE BIRD AFTER GAME OVER
            this.rotation = 0 * DEGREE;
        }else{
            this.speed += this.gravity;
            this.y += this.speed;
            
            if(this.y + this.h/2 >= cvs.height - fg.h){
                this.y = cvs.height - fg.h - this.h/2;
                if(state.current == state.game){
                    state.current = state.over;
                    sendscore(score);
                    document.getElementById("hiscore").innerHTML = myhiscore;
                    document.getElementById("score").innerHTML = myscore;
                    drawtable(myfrens);
                    DIE.play();
                }
            }
            
            // IF THE SPEED IS GREATER THAN THE JUMP MEANS THE BIRD IS FALLING DOWN
            if(this.speed >= this.jump){
                this.rotation = 90 * DEGREE;
                this.frame = 1;
            }else{
                this.rotation = -25 * DEGREE;
            }
        }
        
    },
    speedReset : function(){
        this.speed = 0;
    }
}

// GET READY MESSAGE
const getReady = {
    sX : 0,
    sY : 228,
    w : 173,
    h : 152,
    x : cvs.width/2 - 173/2,
    y : 80,
    
    draw: function(){
        if(state.current == state.getReady){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// GAME OVER MESSAGE
const gameOver = {
    sX : 175,
    sY : 228,
    w : 225,
    h : 202,
    x : cvs.width/2 - 225/2,
    y : 90,
    
    draw: function(){
        if(state.current == state.over){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// PIPES
const pipes = {
    position : [],
    
    top : {
        sX : 553,
        sY : 0
    },
    bottom:{
        sX : 502,
        sY : 0
    },
    
    w : 53,
    h : 400,
    gap : 85,
    maxYPos : -150,
    dx : 2,
    
    draw : function(){
        for(let i  = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let topYPos = p.y;
            let bottomYPos = p.y + this.h + this.gap;
            
            // top pipe
            ctx.drawImage(sprite, this.top.sX, this.top.sY, this.w, this.h, p.x, topYPos, this.w, this.h);  
            
            // bottom pipe
            ctx.drawImage(sprite, this.bottom.sX, this.bottom.sY, this.w, this.h, p.x, bottomYPos, this.w, this.h);  
        }
    },
    
    update: function(){
        if(state.current !== state.game) return;
        
        if(frames%100 == 0){
            this.position.push({
                x : cvs.width,
                y : this.maxYPos * ( Math.random() + 1)
            });
        }
        for(let i = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let bottomPipeYPos = p.y + this.h + this.gap;
            
            // COLLISION DETECTION
            // TOP PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > p.y && bird.y - bird.radius < p.y + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                drawtable(myfrens);
                HIT.play();
            }
            // BOTTOM PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > bottomPipeYPos && bird.y - bird.radius < bottomPipeYPos + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                drawtable(myfrens);
                HIT.play();
            }
            
            // MOVE THE PIPES TO THE LEFT
            p.x -= this.dx;
            
            // if the pipes go beyond canvas, we delete them from the array
            if(p.x + this.w <= 0){
                this.position.shift();
                score.value += 1;
                SCORE_S.play();
                score.best = Math.max(score.value, score.best);
                localStorage.setItem("best", score.best);
            }
        }
    },
    
    reset : function(){
        this.position = [];
    }
    
}

// SCORE
const score= {
    best : parseInt(localStorage.getItem("best")) || (myhiscore ? myhiscore : 0),
    value : 0,
    
    draw : function(){
        ctx.fillStyle = "#FFF";
        ctx.strokeStyle = "#000";
        
        if(state.current == state.game){
            ctx.lineWidth = 2;
            ctx.font = "35px Teko";
            ctx.fillText(this.value, cvs.width/2, 50);
            ctx.strokeText(this.value, cvs.width/2, 50);
            
        }else if(state.current == state.over){
            // SCORE VALUE
            ctx.font = "25px Teko";
            ctx.fillText(this.value, 225, 186);
            ctx.strokeText(this.value, 225, 186);
            // BEST SCORE
            ctx.fillText(this.best, 225, 228);
            ctx.strokeText(this.best, 225, 228);
        }
    },
    
    reset : function(){
        this.value = 0;
    }
}

// DRAW
function draw(){
    ctx.fillStyle = "#70c5ce";
    ctx.fillRect(0, 0, cvs.width, cvs.height);
    
    bg.draw();
    pipes.draw();
    fg.draw();
    bird.draw();
    getReady.draw();
    gameOver.draw();
    score.draw();
}

// UPDATE
function update(){
    bird.update();
    fg.update();
    pipes.update();
}

// LOOP
function loop(){
    update();
    draw();
    frames++;
    
    requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>
```


##  Making It Prettier

We have a final version of the interface with a cleaned-up table courtesy of ~haddef-sigwen:

**`/app/flappy/index.html`**:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Original Flappy Bird -JavaScript</title>
    <link rel="preconnect" href="https://fonts.googleapis.com"> 
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin> 
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&family=Teko:wght@700&display=swap" rel="stylesheet">
    <style>
        body, html {
            font-family: "Inter", sans-serif;
            height: 100%;
            width: 100%;
            margin: 0;
        }
        body {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        body > div {
            max-width: 320px;
            width: 100%;
        }
        table {
            width: 100%;
            text-align: center;
        }
        tr:first-of-type {
            font-weight: 700;
            color: #918C84;
        }
        canvas {
            border: 1px solid #000;
            display: block;
            margin: 0 auto;
        }
        #ship, #score, #hiscore {
            display: block;
            color: #000;
            font-weight: 400;
        }
        #bird {
            image-rendering: pixelated;
        }
        #ship, .ship {
            font-family: monospace;
        }
        #our {
            display: flex;
        }
        #our > p {
            margin: 1rem;
            font-weight: 700;
            color: #918C84;
            text-align: center;
        }
    </style>
</head>
<body>
    <div>
<canvas id="bird" width="320" height="480"></canvas>

<div id="our">
<p>Ship
    <span id="ship"></span>
</p>
<p>
    Last score
    <span id="score"></span>
</p>
<p>High score <span id="hiscore"></span></p>
</div>

<p style="font-weight: 700; text-align: center; margin-top: 2rem;">Leaderboard</p>
<p id="board">
<div id="frens"></div>
</p>
</div>

<script type="module">

// URBIT STATE
async function getmyship() {
        const response = await fetch('/apps/flap/whoami');
        return response.text();
    }
var myshipname = await getmyship();
document.getElementById("ship").innerHTML = myshipname;

async function gethiscore() {
        const response = await fetch('/apps/flap/hiscore');
        return response.text();
    }

var myhiscore = await gethiscore();

async function updateHiScore() {
    let newHiScore = await gethiscore();
    myhiscore = newHiScore;
}

document.getElementById("hiscore").innerHTML = myhiscore;

async function getscore() {
        const response = await fetch('/apps/flap/score');
        return response.text();
    }
var myscore = await getscore();
document.getElementById("score").innerHTML = myscore;

//  Send score to Gall agent
function sendscore(score) {
    fetch('/apps/flap', {
        method: 'POST',
        body: JSON.stringify({'gain': {'score': score.value}})
    })
}

//  Draw table of frens
async function getfrens() {
        const response = await fetch('/apps/flap/frens');
        return response.text();
    }
function drawtable(myfrens) {
    var frens = JSON.parse(myfrens);

    var table = document.createElement("table");
    var titleRow = table.insertRow();
    var frenCell = titleRow.insertCell();
    frenCell.innerHTML = "Ship";
    var scoreCell = titleRow.insertCell();
    scoreCell.innerHTML = "Score";
    
    for (let key in frens) {
        var row = table.insertRow();
        var cell = row.insertCell();
        cell.classList += "ship";
        cell.innerHTML = frens[key]['fren'];
        cell = row.insertCell();
        cell.innerHTML = frens[key]['score'];
    }

    // Clear the old table
    const list = document.getElementById("frens");
    while (list.hasChildNodes()) {
        list.removeChild(list.firstChild);
    }
    // Add the new one
    document.getElementById("frens").appendChild(table);
}
var myfrens = await getfrens();

drawtable(myfrens);

// SELECT CVS
const cvs = document.getElementById("bird");
const ctx = cvs.getContext("2d");
ctx.imageSmoothingEnabled = false;

// GAME VARS AND CONSTS
let frames = 0;
const DEGREE = Math.PI/180;

// LOAD SPRITE IMAGE
const sprite = new Image();
sprite.src = "https://raw.githubusercontent.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/img/sprite.png";

// LOAD SOUNDS
const SCORE_S = new Audio();
SCORE_S.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_point.wav";

const FLAP = new Audio();
FLAP.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_flap.wav";

const HIT = new Audio();
HIT.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_hit.wav";

const SWOOSHING = new Audio();
SWOOSHING.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_swooshing.wav";

const DIE = new Audio();
DIE.src = "https://raw.github.com/CodeExplainedRepo/Original-Flappy-bird-JavaScript/master/audio/sfx_die.wav";

// GAME STATE
const state = {
    current : 0,
    getReady : 0,
    game : 1,
    over : 2
}

// START BUTTON COORD
const startBtn = {
    x : 120,
    y : 263,
    w : 83,
    h : 29
}

// CONTROL THE GAME
cvs.addEventListener("click", function(evt){
    switch(state.current){
        case state.getReady:
            state.current = state.game;
            SWOOSHING.play();
            break;
        case state.game:
            if(bird.y - bird.radius <= 0) return;
            bird.flap();
            FLAP.play();
            break;
        case state.over:
            let rect = cvs.getBoundingClientRect();
            let clickX = evt.clientX - rect.left;
            let clickY = evt.clientY - rect.top;
            
            // CHECK IF WE CLICK ON THE START BUTTON
            if(clickX >= startBtn.x && clickX <= startBtn.x + startBtn.w && clickY >= startBtn.y && clickY <= startBtn.y + startBtn.h){
                pipes.reset();
                bird.speedReset();
                score.reset();
                state.current = state.getReady;
            }
            break;
    }
});


// BACKGROUND
const bg = {
    sX : 0,
    sY : 0,
    w : 275,
    h : 226,
    x : 0,
    y : cvs.height - 226,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    }
    
}

// FOREGROUND
const fg = {
    sX: 276,
    sY: 0,
    w: 224,
    h: 112,
    x: 0,
    y: cvs.height - 112,
    
    dx : 2,
    
    draw : function(){
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        
        ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x + this.w, this.y, this.w, this.h);
    },
    
    update: function(){
        if(state.current == state.game){
            this.x = (this.x - this.dx)%(this.w/2);
        }
    }
}

// BIRD
const bird = {
    animation : [
        {sX: 276, sY : 112},
        {sX: 276, sY : 139},
        {sX: 276, sY : 164},
        {sX: 276, sY : 139}
    ],
    x : 50,
    y : 150,
    w : 34,
    h : 26,
    
    radius : 12,
    
    frame : 0,
    
    gravity : 0.15,
    jump : 2.6,
    speed : 0,
    rotation : 0,
    
    draw : function(){
        let bird = this.animation[this.frame];
        
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.drawImage(sprite, bird.sX, bird.sY, this.w, this.h,- this.w/2, - this.h/2, this.w, this.h);
        
        ctx.restore();
    },
    
    flap : function(){
        this.speed = - this.jump;
    },
    
    update: function(){
        // IF THE GAME STATE IS GET READY STATE, THE BIRD MUST FLAP SLOWLY
        this.period = state.current == state.getReady ? 10 : 5;
        // WE INCREMENT THE FRAME BY 1, EACH PERIOD
        this.frame += frames%this.period == 0 ? 1 : 0;
        // FRAME GOES FROM 0 To 4, THEN AGAIN TO 0
        this.frame = this.frame%this.animation.length;
        
        if(state.current == state.getReady){
            this.y = 150; // RESET POSITION OF THE BIRD AFTER GAME OVER
            this.rotation = 0 * DEGREE;
        }else{
            this.speed += this.gravity;
            this.y += this.speed;
            
            if(this.y + this.h/2 >= cvs.height - fg.h){
                this.y = cvs.height - fg.h - this.h/2;
                if(state.current == state.game){
                    state.current = state.over;
                    sendscore(score);
                    document.getElementById("hiscore").innerHTML = myhiscore;
                    document.getElementById("score").innerHTML = myscore;
                    drawtable(myfrens);
                    DIE.play();
                }
            }
            
            // IF THE SPEED IS GREATER THAN THE JUMP MEANS THE BIRD IS FALLING DOWN
            if(this.speed >= this.jump){
                this.rotation = 90 * DEGREE;
                this.frame = 1;
            }else{
                this.rotation = -25 * DEGREE;
            }
        }
        
    },
    speedReset : function(){
        this.speed = 0;
    }
}

// GET READY MESSAGE
const getReady = {
    sX : 0,
    sY : 228,
    w : 173,
    h : 152,
    x : cvs.width/2 - 173/2,
    y : 80,
    
    draw: function(){
        if(state.current == state.getReady){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// GAME OVER MESSAGE
const gameOver = {
    sX : 175,
    sY : 228,
    w : 225,
    h : 202,
    x : cvs.width/2 - 225/2,
    y : 90,
    
    draw: function(){
        if(state.current == state.over){
            ctx.drawImage(sprite, this.sX, this.sY, this.w, this.h, this.x, this.y, this.w, this.h);
        }
    }
}

// PIPES
const pipes = {
    position : [],
    
    top : {
        sX : 553,
        sY : 0
    },
    bottom:{
        sX : 502,
        sY : 0
    },
    
    w : 53,
    h : 400,
    gap : 85,
    maxYPos : -150,
    dx : 2,
    
    draw : function(){
        for(let i  = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let topYPos = p.y;
            let bottomYPos = p.y + this.h + this.gap;
            
            // top pipe
            ctx.drawImage(sprite, this.top.sX, this.top.sY, this.w, this.h, p.x, topYPos, this.w, this.h);  
            
            // bottom pipe
            ctx.drawImage(sprite, this.bottom.sX, this.bottom.sY, this.w, this.h, p.x, bottomYPos, this.w, this.h);  
        }
    },
    
    update: function(){
        if(state.current !== state.game) return;
        
        if(frames%100 == 0){
            this.position.push({
                x : cvs.width,
                y : this.maxYPos * ( Math.random() + 1)
            });
        }
        for(let i = 0; i < this.position.length; i++){
            let p = this.position[i];
            
            let bottomPipeYPos = p.y + this.h + this.gap;
            
            // COLLISION DETECTION
            // TOP PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > p.y && bird.y - bird.radius < p.y + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                drawtable(myfrens);
                HIT.play();
            }
            // BOTTOM PIPE
            if(bird.x + bird.radius > p.x && bird.x - bird.radius < p.x + this.w && bird.y + bird.radius > bottomPipeYPos && bird.y - bird.radius < bottomPipeYPos + this.h){
                state.current = state.over;
                sendscore(score);
                document.getElementById("hiscore").innerHTML = myhiscore;
                document.getElementById("score").innerHTML = myscore;
                drawtable(myfrens);
                HIT.play();
            }
            
            // MOVE THE PIPES TO THE LEFT
            p.x -= this.dx;
            
            // if the pipes go beyond canvas, we delete them from the array
            if(p.x + this.w <= 0){
                this.position.shift();
                score.value += 1;
                SCORE_S.play();
                score.best = Math.max(score.value, score.best);
                localStorage.setItem("best", score.best);
            }
        }
    },
    
    reset : function(){
        this.position = [];
    }
    
}

// SCORE
const score= {
    best : parseInt(localStorage.getItem("best")) || (myhiscore ? myhiscore : 0),
    value : 0,
    
    draw : function(){
        ctx.fillStyle = "#FFF";
        ctx.strokeStyle = "#000";
        
        if(state.current == state.game){
            ctx.lineWidth = 2;
            ctx.font = "35px Teko";
            ctx.fillText(this.value, cvs.width/2, 50);
            ctx.strokeText(this.value, cvs.width/2, 50);
            
        }else if(state.current == state.over){
            // SCORE VALUE
            ctx.font = "25px Teko";
            ctx.fillText(this.value, 225, 186);
            ctx.strokeText(this.value, 225, 186);
            // BEST SCORE
            ctx.fillText(this.best, 225, 228);
            ctx.strokeText(this.best, 225, 228);
        }
    },
    
    reset : function(){
        updateHiScore();
        this.value = 0;
    }
}

// DRAW
function draw(){
    ctx.fillStyle = "#70c5ce";
    ctx.fillRect(0, 0, cvs.width, cvs.height);
    
    bg.draw();
    pipes.draw();
    fg.draw();
    bird.draw();
    getReady.draw();
    gameOver.draw();
    score.draw();
}

// UPDATE
function update(){
    bird.update();
    fg.update();
    pipes.update();
}

// LOOP
function loop(){
    update();
    draw();
    frames++;
    
    requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>
```

##  What's Next?

Some things to think about:

- What about other games?
- What about other game state?
- What about serving components straight from the ship (like `wav` and `png`)?
