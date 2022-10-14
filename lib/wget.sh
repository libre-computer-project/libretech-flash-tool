WGET_getHeaders(){
	wget -S --spider "$1" 2>&1
}