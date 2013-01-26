#!/bin/bash
# Evgeny.Stepanischev Jan 2013 http://bolknote.ru/

. b-oo.sh

@Class Base
    @Dim cnt

    @Dim
    __construct() {
        This[cnt]=0
    }

    @Dim
    IncCnt() {
        let 'This[cnt]++'
    }

    @Dim
    GetCnt() {
        [ "$This[cnt]" -gt 1 ] && s=s
        echo $Self said $This[cnt] time$s
    }
@End

@Class Dog Base
    @Dim
    say() {
        $This.IncCnt
        echo 'Bow-wow!'
    }

    @Dim
    __destruct() {
        echo "$Self dying!"
    }
@End

@Class Car Base
    @Dim
    say() {
        $This.IncCnt
        echo 'Beep'
    }
@End

@Class Proxy
    @Dim obj

    @Dim Static
    getInstance() {
        $1.New Self[obj]
        @Ret $2 $Self[obj]
    }
@End

Proxy.getInstance Car car
Proxy.getInstance Dog dog

$car.say
$car.say
$car.GetCnt

$dog.cnt =100

$dog.say
$dog.GetCnt

Dog.New anothedog

$anothedog.say
$anothedog.say

$anothedog.GetCnt

unset anothedog

@Class.gc

echo Done