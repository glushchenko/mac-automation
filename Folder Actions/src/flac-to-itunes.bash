#!/bin/bash

##################################
# FLAC to iTunes importer v0.5.1 #
##################################

export PATH="/usr/local/bin:$PATH"

processAlbumFolder() {
	SRC=$1
	DST="$HOME/Music/iTunes/iTunes Media/Automatically Add to iTunes"

	if [ ! -d "$DST" ]; then
		ln -s $HOME/Music/iTunes/iTunes\ Media/Automatically\ Add\ to\ iTunes.localized $HOME/Music/iTunes/iTunes\ Media/Automatically\ Add\ to\ iTunes
		mkdir -p $DST		
	fi

	# sleep while download active
	while [ $(ps aux | grep lftp | grep -v grep | wc -l) -gt "0" ]; do
		sleep 5
	done

	LABEL=$(xattr "$SRC" | grep flac_imported | wc -l)
	FOUND=$(find "$SRC" -name "*.flac" | wc -l)

	COVER_NAME="converter_cover.jpg"
	META_NAME="converter_metadata.txt"

	COVER_PATH="$SRC/$COVER_NAME"
	META_PATH="$SRC/$META_NAME"

	# set parsed label 
	xattr -w flac_imported true "$SRC"

	if [ "$LABEL" -eq "0" ] && [ -n "$SRC" ] && [ "$FOUND" -gt "0" ]; then
		FIRST=$(find "$SRC" -name "*.flac" -print | head -n 1)
		
		# trying to extract cover from current track
		ffmpeg -i "$FIRST" "$COVER_PATH"
		FF=$?
		
		# convert for test AP
		ffmpeg -y -i "$FIRST" -c:a alac -vn "$FIRST.m4a"
		
		# trying to embed cover
		AtomicParsley "$FIRST.m4a" --artwork "$COVER_PATH" --overWrite
		AP=$?
		
		# if failed, trying download from sacad
		if [ "${FF}" -ne "0" ] || [ "${AP}" -ne "0" ]; then
		    ffmpeg -i "$FIRST" -f ffmetadata "$META_PATH"
		
		    ARTIST=$(cat "$META_PATH" | grep -i artist= | head -1 | sed -e "s/artist=//I" | xargs)
		    ALBUM_ARTIST=$(cat "$META_PATH" | grep -i "^album.*artist=" | head -1 | sed -e "s/album.*artist=//I" | xargs)
		    ALBUM=$(cat "$META_PATH" | grep -i album= | head -1 | sed -e "s/album=//I" | sed -e "s/(.*digipack.*)\|(.*deluxe.*)\|(.*bonus.*)\|(.*japan.*)\|(.*remaster.*)\|(.*mfsl.*)//I" | xargs)
		
		    if [ "$ALBUM_ARTIST" ]; then
		        ARTIST=$ALBUM_ARTIST
		    fi
		
		    SACAD=$(sacad -d "$ARTIST" "$ALBUM" 600 "$COVER_PATH" 2>&1)

    		if [[ $SACAD == *"No results"* ]]
    		then
        		ALBUM=$(cat "$META_PATH" | grep -i album= | head -1 | sed -e "s/album=//I" | sed -e "s/(.*)//I" | xargs)
				sacad -d "$ARTIST" "$ALBUM" 600 "$COVER_PATH"
    		fi

	        echo "Detected artist/album: '$ARTIST/$ALBUM'"
	        echo "Path: $COVER_PATH"
		
		    rm "$META_PATH"
		fi

		find "$SRC" -name "*.flac" -exec ffmpeg -y -i '{}' -c:a alac -vn '{}'.m4a \;
		find "$SRC" -name "*.m4a" -exec AtomicParsley '{}' --artwork "$COVER_PATH" --overWrite \;
		find "$SRC" -name "*.m4a" -exec mv '{}' "$DST" \;
		
		rm "$COVER_PATH"
		
		/usr/bin/osascript -e 'display notification "New ALAC tracks imported " with title "iTunes"'
	fi
}

LOCK="/tmp/flac-to-itunes.lock"
trap "rm -f $LOCK" SIGINT SIGTERM

if [ -e "$LOCK" ] || [ -z "$1" ]
then
    echo "flac to itunes is running already."
    exit
else
    touch "$LOCK"

	while [ $(find "$BASE/"* -maxdepth 0 -type d | wc -l) -gt $(find "$BASE/"* -maxdepth 0 -type d -exec xattr "{}" \+ | grep flac_imported | wc -l) ]; do
		BASE=$(dirname "$1")

		IFS=$'\n'

		for DIRECTORY in $(find "$BASE/"* -maxdepth 0 -type d); 
		do
			IMPORTED=$(xattr "$DIRECTORY" | grep flac_imported | wc -l)
			if [ "$IMPORTED" -eq "0" ]; then
				echo "Album: $DIRECTORY" >> /tmp/flac_imported

				processAlbumFolder "$DIRECTORY"
			fi
		done
	done

	rm -f "$LOCK"
    trap - SIGINT SIGTERM
    exit
fi