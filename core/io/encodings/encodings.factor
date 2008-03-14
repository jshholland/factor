! Copyright (C) 2008 Daniel Ehrenberg.
! See http://factorcode.org/license.txt for BSD license.
USING: math kernel sequences sbufs vectors namespaces
growable strings io classes continuations combinators
io.styles io.streams.plain splitting
io.streams.duplex byte-arrays sequences.private ;
IN: io.encodings

! The encoding descriptor protocol

GENERIC: decode-char ( stream encoding -- char/f )

GENERIC: encode-char ( char stream encoding -- )

GENERIC: <decoder> ( stream decoding -- newstream )

GENERIC: <encoder> ( stream encoding -- newstream )

: replacement-char HEX: fffd ;

! Decoding

<PRIVATE

TUPLE: decode-error ;

: decode-error ( -- * ) \ decode-error construct-empty throw ;

TUPLE: decoder stream code cr ;
M: tuple-class <decoder> construct-empty <decoder> ;
M: tuple <decoder> f decoder construct-boa ;

: >decoder< ( decoder -- stream encoding )
    { decoder-stream decoder-code } get-slots ;

: cr+ t swap set-decoder-cr ; inline

: cr- f swap set-decoder-cr ; inline

: line-ends/eof ( stream str -- str ) f like swap cr- ; inline

: line-ends\r ( stream str -- str ) swap cr+ ; inline

: line-ends\n ( stream str -- str )
    over decoder-cr over empty? and
    [ drop dup cr- stream-readln ] [ swap cr- ] if ; inline

: handle-readln ( stream str ch -- str )
    {
        { f [ line-ends/eof ] }
        { CHAR: \r [ line-ends\r ] }
        { CHAR: \n [ line-ends\n ] }
    } case ;

: fix-read ( stream string -- string )
    over decoder-cr [
        over cr-
        "\n" ?head [
            over stream-read1 [ add ] when*
        ] when
    ] when nip ;

: read-loop ( n stream -- string )
    over 0 <string> [
        [
            >r stream-read1 dup
            [ swap r> set-nth-unsafe f ] [ r> 3drop t ] if
        ] 2curry find-integer
    ] keep swap [ head ] when* ;

M: decoder stream-read
    tuck read-loop fix-read ;

: (read-until) ( buf quot -- string/f sep/f )
    ! quot: -- char keep-going?
    dup call
    [ >r drop "" like r> ]
    [ pick push (read-until) ] if ; inline

M: decoder stream-read-until
    SBUF" " clone -rot >decoder<
    [ decode-char dup rot memq? ] 3curry (read-until) ;

: fix-read1 ( stream char -- char )
    over decoder-cr [
        over cr-
        dup CHAR: \n = [
            drop dup stream-read1
        ] when
    ] when nip ;

M: decoder stream-read1
    dup >decoder< decode-char fix-read1 ;

M: decoder stream-readln ( stream -- str )
    "\r\n" over stream-read-until handle-readln ;

M: decoder dispose decoder-stream dispose ;

! Encoding

TUPLE: encode-error ;

: encode-error ( -- * ) \ encode-error construct-empty throw ;

TUPLE: encoder stream code ;
M: tuple-class <encoder> construct-empty <encoder> ;
M: tuple <encoder> encoder construct-boa ;

: >encoder< ( encoder -- stream encoding )
    { encoder-stream encoder-code } get-slots ;

M: encoder stream-write1
    >encoder< encode-char ;

M: encoder stream-write
    >encoder< [ encode-char ] 2curry each ;

M: encoder dispose encoder-stream dispose ;

INSTANCE: encoder plain-writer

! Rebinding duplex streams which have not read anything yet

: reencode ( stream encoding -- newstream )
    over encoder? [ >r encoder-stream r> ] when <encoder> ;

: redecode ( stream encoding -- newstream )
    over decoder? [ >r decoder-stream r> ] when <decoder> ;
PRIVATE>

: <encoder-duplex> ( stream-in stream-out encoding -- duplex )
    tuck reencode >r redecode r> <duplex-stream> ;
