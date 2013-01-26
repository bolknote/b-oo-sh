#!/bin/bash
# Evgeny.Stepanischev Jan 2013 http://bolknote.ru/

:|sed -E '' 2>&- && Class.sed() { sed -E "$@"; } || Class.sed() { sed -r "$@"; }

Class.rename() {
    Class.copy "$1" "$2"
    unset -f $1
}

Class.copy() {
    if [ "$3" ]; then
        local vars=CLASSES_V_${4//.*}

        eval "$2() { local This=$3 Parent=$3.Parent Self=$4; $(declare -f $1 |
            tail -f +4 | # delete local Self
            Class.sed 's/\{?This\[(@'${!vars}')\]\}?/'${3#*.}'__\1/g')"
    else
        local vars=CLASSES_V_${2//.*}

        eval "$2() { local Self=${2//.*}; $(declare -f $1 |
            tail -f +3 |
            Class.sed 's/\{?Self\[(@'${!vars}')\]\}?/'${2//.*}'_Static_\1/g')"
    fi
}

Class.var() {
    local name=${1#*.}__$2

    if [ -z "$3" ]; then
        echo -n ${!name}
    else
        # присваиваем значения, пропуская знак «равно»
        printf -v $name "${3#=}"
    fi
}

Class.exists() {
    typeset -F | grep -qF "$1"
}

Class.append() {
    if [ "$2" ]; then
        local props=CLASSES_V_$CLASS_NAME
        printf -v $props "%s" "${!props}|$2"
    else
        local len=${#BASH_SOURCE[@]}
        local file="${BASH_SOURCE[$len-1]}"
        local line=${BASH_LINENO[$len-2]}

        local name=( $(
            awk -F ' *; *| *\\(' \
            'NR=='$line' {print $2}
            NR=='$line'+1 {gsub("[ \t]", "", $1);print $1;exit}'\
            "$file")
        )

        local methods=CLASSES_M_$CLASS_NAME
        printf -v $methods "%s" "${!methods} $CLASS_NAME.$1$name"
    fi
}

@Dim() {
    if [ "$1" == "Static" ]; then
        Class.append
    else
        Class.append Public. "$1"
    fi
}

@Ret() {
    local name="$1"
    shift
    printf -v "$name" "$@"
}

@Class() {
    CLASS_NAME=($@)
    local name vars

    for name in ${CLASS_NAME[@]:1}; do
        vars=CLASSES_V_$name

        printf -v CLASSES_V_$CLASS_NAME "%s" ${!vars}
    done
}

Class.New() {
    local file="${BASH_SOURCE[1]}"
    local line=${BASH_LINENO[1]}
    local methods=CLASSES_M_$1

    # Выбираем уникальное имя для объекта
    local obj=@:Object.f$(md5 <<< "$1 $file $line $RANDOM $(date)")

    # Копируем все методы объекта из класса и из родительских классов
    for name in ${!methods}; do
        local newname=$obj.${name##*.}

        if Class.exists $newname; then
            newname="${newname%.*}.Parent.${newname//*.}"
        fi

        Class.copy $name $newname $obj "$1"
    done

    # Создаём перехватывающие функции для свойств
    local vars=CLASSES_V_$1
    for name in $(tr '|' ' ' <<< "${!vars}"); do
        eval "$obj.$name() { Class.var \"$obj\" \"$name\" \"\$@\"; }"
    done

    # Передаём имя объекта в переменную
    printf -v $2 $obj
    shift 2

    # Вызываем конструктор, если он есть
    Class.exists $obj.__construct && $obj.__construct "$@"
}

@End() {
    local methods name parent
    local parentmethods=()

    eval "${CLASS_NAME}.New() { Class.New $CLASS_NAME \"\$@\"; }"

    if [ ${#CLASS_NAME[@]} -gt 1 ]; then
        for parent in ${CLASS_NAME[@]:1}; do
            methods=CLASSES_M_$parent

            parentmethods="$parentmethods ${!methods}"
        done
    fi

    methods=CLASSES_M_$CLASS_NAME

    for name in ${!methods}; do
        Class.rename ${name##*.} $name
    done

    unset CLASS_NAME

    printf -v $methods "${!methods} $parentmethods"
}

# Функция, уничтожающая класс
@Destroy() {
    # вызываем деструктор, если он есть
    Class.exists $1.__destruct && $1.__destruct

    # Удаляем все имена функций объекта
    for name in $(typeset -F | grep -o " $1[^ ]*"); do
        unset -f "$name"
    done

    # Удаляем все свойства объекта
    for name in $( (set -o posix; set) | grep -o "^${1//*.}__[^=]*=" ); do
        unset ${name%%=}
    done
}

# Функция, ищущая неупоминаемые объекты и уничтожающая их
@Class.gc() {
    # Значения всех переменных
    local vars=$(set -o posix; set)

    # Ищем все объекты и смотрим, упоминаются ли они в переменных
    for name in $( typeset -F | grep -o " @:Object\.[^ ]*" | cut -d. -f2 | sort -ud ); do
        if ! grep -q "@:Object.$name$" <<< "$vars"; then
            @Destroy "@:Object.$name"
        fi
    done
}

# Включение автоматического сборщика мусора (медленно!)
@Class.gc.on() {
    trap @Class.gc DEBUG EXIT
}