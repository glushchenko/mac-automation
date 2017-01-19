export PATH=/usr/local/bin:$PATH

PWD=$1
CURRENT=$(basename "$PWD")

SESSION_EXIST=$(tmux ls | grep attached | wc -l)

if [ $SESSION_EXIST -gt 0 ]; then
	open /Applications/Utilities/Terminal.app
    	tmux neww -c "$PWD" -n "$CURRENT"
else
	osascript -e 'tell application "Terminal" to do script "tmux"'
	sleep 1
	tmux neww -c "$PWD" -n "$CURRENT"

	# reorder for position 1
	tmux move-window -t 2
	tmux kill-window -t 1
    	tmux move-window -t 1

	open /Applications/Utilities/Terminal.app
fi