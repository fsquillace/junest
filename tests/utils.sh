function is_equal(){
    if [ "$1" == "$2" ]
    then
        return 0
    else
        echo "$1!=$2"
        return 1
    fi
}


