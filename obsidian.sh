#!/data/data/com.termux/files/usr/bin/bash

echo "Script Version 0.4.1.5"
echo "This script is used to facilitate configuration of git for obsidian using termux. "
echo -e "Obsidian Android path: Obsidian/Local/your_obsidian\n"

SCRIPTS_TERMUX_DIR=".shortcuts"
OBSIDIAN_DIR="Local"
GIT_DIR="Remote"
ANDROID_DIR="Obsidian"

export HOME_PATH="/data/data/com.termux/files/home"
export STORAGE_PATH="/storage/emulated/0"
export REPOS_PATH="$STORAGE_PATH/$ANDROID_DIR"
export OBSIDIAN_PATH="$REPOS_PATH/$OBSIDIAN_DIR"
export GIT_PATH="$REPOS_PATH/$GIT_DIR"
export SCRIPTS_TERMUX_PATH="$STORAGE_PATH/$SCRIPTS_TERMUX_DIR"

#export NOTIFICATION_PATH="$STORAGE_PATH/sync-error-notification"
#export LAST_MOBILE_SYNC_PATH="$HOME/last_sync.log"

# Define functions for each menu option
function install_required_deps()
{
    apt update
    apt upgrade -y
    pkg install openssh -y
    pkg install git -y
    pkg install cronie termux-services -y
    echo
    echo "-------------------------------------------------------"
    echo "You should reboot the termux for changes to take effect."
    echo "-------------------------------------------------------"
}

function access_storage()
{
    termux-setup-storage
}

function configure_git() {

    name="$1"
    email="$2"

    git config --global user.name "$name"
    git config --global user.email "$email"

    git config --global credential.helper store
    git config --global pull.rebase false
    git config --global --add safe.directory '*'
    git config --global core.protectNTFS false
    git config --global core.longpaths true
}

function generate_ssh_key() {
    email="$1"
    # Check if key already exists
    if [ ! -f $HOME_PATH/.ssh/id_ed25519 ]; then
        # Generate key non-interactively
        ssh-keygen -q -t ed25519 -N "" -f $HOME_PATH/.ssh/id_ed25519 -C "$email"
        echo "Generated new SSH key with email $email"
    else
        echo "SSH key already exists"
    fi
    echo "Here is your SSH public key. You can paste it inside Github"
    echo "------------"
    cat $HOME_PATH/.ssh/id_ed25519.pub
    echo "------------"
    eval "$(ssh-agent -s)"
    ssh-add
}

function clone_repo() {
    folder="$1"
    git_url="$2"

    # check if remote repository exists
    if timeout 30s git ls-remote -h "$git_url" &> /dev/null; then
        if [ -e "$OBSIDIAN_PATH/$folder" ];then
            echo "Repository Local: $GIT_PATH/$folder nom-empty"
            echo -e "Remove the $folder, after clone git again\n" 
        else
            echo "Git Folder: $GIT_PATH/$folder"
            echo "Obsidian Folder: $OBSIDIAN_PATH/$folder"
            echo -e "Git Url: $git_url\n"
            write_to_path_if_not_exists "$OBSIDIAN_PATH"
            write_to_path_if_not_exists "$GIT_PATH"

            cd "$GIT_PATH/" || { echo "Failure while changing directory into $GIT_PATH"; exit 1; }
            if [ -e "$GIT_PATH/$folder" ];then
               echo -e "Remote Repository $folder already exist into Android: $ANDROID_DIR/$GIT_DIR/$folder, cleanning $folder\n";
               rm -R "$GIT_PATH/$folder"
               write_to_path_if_not_exists "$GIT_PATH/$folder" 
            else
               write_to_path_if_not_exists "$GIT_PATH/$folder"
             fi

            # clone repository remote and create a worktree on repository local  
            git --git-dir "$GIT_PATH/$folder" --work-tree "$OBSIDIAN_PATH/$folder" clone "$git_url"
            cd "$GIT_PATH/$folder" || { echo "Failure while changing directory into $GIT_PATH/$folder"; exit 1; }
            echo "Trying force Checkout"
            git worktree add --checkout "$OBSIDIAN_PATH/$folder" --force
            echo -e "Clone Success\n"
        fi
    else
        echo -e "Repository git: $git_url no access, check git url and try again !!!\n"
        #sleep 5
        #bash "$PWD/obsidian.sh"
        #exit 1
    fi
}

# add gitignore file
function add_gitignore_entries() {
    folder_name="$1"
    cd "$OBSIDIAN_PATH/$folder_name" || { echo "Failure while changing directory into $OBSIDIAN_PATH/$folder_name"; exit 1; }
    GITIGNORE=".gitignore"

    ENTRIES=".trash/
    .obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    if [ ! -f "$GITIGNORE" ]; then
        touch "$GITIGNORE"
    fi

    for entry in $ENTRIES; do
        if ! grep -q -Fx "$entry" "$GITIGNORE"; then
            echo "$entry" >> "$GITIGNORE"
        fi
    done

}

function add_gitattributes_entry() {
    folder_name="$1"
    cd "$OBSIDIAN_PATH/$folder_name" || { echo "Failure while changing directory into $OBSIDIAN_PATH/$folder_name"; exit 1; }
    GITATTRIBUTES=".gitattributes"
    ENTRY="*.md merge=union"

    if [ ! -f "$GITATTRIBUTES" ]; then
        touch "$GITATTRIBUTES"
    fi

    if ! grep -q -F "$ENTRY" "$GITATTRIBUTES"; then
        echo "$ENTRY" >> "$GITATTRIBUTES"
    fi

}

function remove_files_from_git()
{
    folder_name="$1"
    cd "$OBSIDIAN_PATH/$folder_name" || { echo "Failure while changing directory into $OBSIDIAN_PATH/$folder_name"; exit 1; }

    FILES=".obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    for file in $FILES; do
        if [ -f "$file" ]; then
            cd "$GIT_PATH/$folder_name" || { echo "Failure while changing directory into $OBSIDIAN_PATH/$folder_name"; exit 1; }
            git rm --cached "$file"
        fi
    done
    cd "$GIT_PATH/$folder_name" || { echo "Failure while changing directory into $OBSIDIAN_PATH/$folder_name"; exit 1; }
    if git status | grep "new file" ; then
        git commit -am "Remove ignored files"
    fi

}

function write_to_path_if_not_exists()
{
    path="$1"
    if [ -e "$path" ];then
	    echo " Checking path: $path, checked!";
    else
	    echo " Creating path: ${path}! ";
	    mkdir -p ${path};
	    [ -e "${path}" ] && echo "  $path, created success!"
    fi 
}

function write_to_file_if_not_exists()
{
    content="$1"
    file="$2"
    if [ ! -f "$file" ]; then
        touch "$file"
        echo "created file $file"
    fi
    if ! grep -qxF "$content" "$file"; then
        echo "$content" >> "$file"
        echo "added scripts to $file"
    fi
}

function configure_git_and_ssh_keys()
{
    while true; do
        read -r -p "Please Enter your name: " name
        if [[ -z "$name" ]]; then
            echo "Invalid input. Please enter a non-empty name."
        else
            echo "Your submitted name: $name"
            break
        fi
    done
    while true; do
        read -r -p "Please Enter your Email: " email
        if [[ $email =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+$ ]]; then
            echo "Your submitted email: $email"
            break
        else
            echo "Invalid input. Please enter a valid email."
        fi
    done
    echo "-------------------------------------"
    configure_git "$name" "$email"
    generate_ssh_key "$email"
}

function clone_obsidian_repo()
{
    while true; do
        echo "Please Enter your git url: "
        read -r git_url
        if [[ -z "$git_url" ]]; then
            echo "Invalid input. Please enter a non-empty git url."
        else
            echo "Your submitted git url: $git_url"
            break
        fi
    done
    base_name=$(basename "$git_url")
    folder_name=${base_name%.*}
    clone_repo "$folder_name" "$git_url"
}

function optimize_repo_for_mobile()
{
    folders=()
    i=1
    for dir in "$OBSIDIAN_PATH"/*; do
        if [ -d "$dir" ]; then
            if git -C "$dir" status &> /dev/null
            then
                folder_name=$(basename "$dir")
                folders+=("$folder_name")
                echo "$i) $folder_name"
                ((i++))
            else
                echo "That $folder is not a Git repository"
                exit 0
            fi
        else
            echo -e "repository doesn't exist. You should clone the repo again.\n"
            exit 0
        fi
    done
    echo "Now which repository do you want to optimize?"
    echo "Select a folder:"
    read -r choice
    folder="${folders[$choice-1]}"
    echo "You selected $folder"
    if [ -d "$OBSIDIAN_PATH/$folder" ]; then
        if git -C "$GIT_PATH/$folder" status &> /dev/null
        then
            add_gitignore_entries "$folder"
            add_gitattributes_entry "$folder"
            remove_files_from_git "$folder"
        else
            echo "That $folder is not a Git repository"
        fi
    else
        echo "Folder $OBSIDIAN_PATH/$folder doesn't exist. You should clone the repo again."
    fi
}

function create_alias_and_git_scripts()
{
    folders=()
    i=1
    for dir in "$OBSIDIAN_PATH"/*; do
        if [ -d "$dir" ]; then
            if git -C "$dir" status &> /dev/null
            then
                folder_name=$(basename "$dir")
                folders+=("$folder_name")
                echo "$i) $folder_name"
                ((i++))
            else
                echo "That $folder is not a Git repository"
                exit 0
            fi
        else
            echo -e "repository doesn't exist. You should clone the repo again.\n"
            exit 0
        fi
    done
    echo "Now which repository do you want to create scripts for?"
    echo "Select a folder:"
    read -r choice
    folder="${folders[$choice-1]}"
        if [ -d "$OBSIDIAN_PATH/$folder" ]; then
            if git -C "$GIT_PATH/$folder" status &> /dev/null; then
                echo "You selected $folder"
            else
                echo "That folder is not a remote Git repository"
                exit 0
            fi
        else
            echo -e "local repository doesn't exist. You should clone the repo again.\n"
            exit 0
        fi

    # call scripts in repository folder from  termux .shortcuts
    TERMUX_SHELL_SCRIPT='#!/data/data/com.termux/files/usr/bin/bash
    source '$GIT_PATH/$folder/.sync_obsidian'
    sync_obsidian '$GIT_PATH/$folder'
    '

    # call scripts in repository folder
    PROFILE_SCRIPT='# Created Automatically by Obsidian-Sync.git
    "Repository: '$folder'"
    if [ -f '$GIT_PATH/$folder/.sync_obsidian' ];then
        source '$GIT_PATH/$folder/.sync_obsidian'
    fi
    if [ -f '$GIT_PATH/$folder/.$folder' ];then
        source '$GIT_PATH/$folder/.$folder'
    fi'

    # create files in home/
    touch "$HOME_PATH/.bashrc"
    touch "$HOME_PATH/.profile"
    touch "$GIT_PATH/$folder/.sync_obsidian"
    chmod +x "$GIT_PATH/$folder/.sync_obsidian"

    # append this to file only if it is not already there
    write_to_file_if_not_exists "$OBSIDIAN_SCRIPT" "$GIT_PATH/$folder/.sync_obsidian"
    write_to_file_if_not_exists "source $HOME_PATH/.profile" "$HOME_PATH/.bashrc"

    # alias
    echo "What do you want your alias to be?"
    read -r alias
    if [ -z $alias ];then
        alias=$folder
    fi
    echo "alias $alias='sync_obsidian $GIT_PATH/$folder'" > "$GIT_PATH/$folder/.$folder"
    echo "$PROFILE_SCRIPT">>"$HOME_PATH/.profile"
    echo "alias $alias created in $GIT_PATH/$folder/.$folder"

    # termux manual script sync
    write_to_path_if_not_exists "$SCRIPTS_TERMUX_PATH"
    cd "$SCRIPTS_TERMUX_PATH/" || { echo "Failure while changing directory into $SCRIPTS_TERMUX_PATH"; exit 1; }
    touch "$SCRIPTS_TERMUX_PATH/$folder.sh"
    echo "$TERMUX_SHELL_SCRIPT" > "$SCRIPTS_TERMUX_PATH/$folder.sh"
    chmod +x "$SCRIPTS_TERMUX_PATH/$folder.sh"

    # termux automatic script sync
    echo "How often is automatic sync supposed to occur??"
    echo "time in minutes: 1 to 59"
    read -r choice

    # start service crontab
    sv-enable crond
    cronjob_editor "*/$choice * * * *" "bash '$SCRIPTS_TERMUX_PATH/$folder.sh'" add

    echo "-------------------------------------------------------"
    echo "You should exit the program for changes to take effect."
    echo "-------------------------------------------------------"

}

function cronjob_editor () {
# usage: cronjob_editor '<interval>' '<command>' <add|remove>

if [[ -z "$1" ]] ;then printf " no interval specified\n" ;fi
if [[ -z "$2" ]] ;then printf " no command specified\n" ;fi
if [[ -z "$3" ]] ;then printf " no action specified\n" ;fi

if [[ "$3" == add ]] ;then
    # add cronjob, no duplication:
    ( crontab -l | grep -v -F -w "$2" ; echo "$1 $2" ) | crontab -
elif [[ "$3" == remove ]] ;then
    # remove cronjob:
    ( crontab -l | grep -v -F -w "$2" ) | crontab -
fi 
} 


# shellcheck disable=SC2016

OBSIDIAN_SCRIPT='function sync_obsidian()
{
    echo "Update repo git path: $1"
    cd "$1" || { echo "Failure while changing directory into $1"; exit 1; }
    git add .
    git commit -m "Android Commit - $(date +%F) $(date +%T) "
    git fetch
    git merge --no-edit
    git add .
    git commit -m "automerge android - $(date +%F) $(date +%T)"
    git push

    # Delete Index.lock
    if [ -e ".git/index.lock" ]; then
        echo "Obsidian repo busy - index.lock - trying later"
        rm -f ".git/index.lock"
    else
        echo "Sync is finished"
    fi
    sleep 2

}
'

# Main menu loop
while true; do
PS3='Please enter your choice: '

options=(
    "Install Required Dependencies"
    "Give Access to Storage"
    "Configure Git and Create SSH Key"
    "Clone Obsidian Git Repo in Termux"
    "Optimize repository for multi-device use"
    "Create Scripts and git commit scripts"
    "Quit"
)

select opt in "${options[@]}"
do
    case $opt in
        "${options[0]}")
            echo -e "Installing Required packages\n"
            install_required_deps
            break
            ;;
        "${options[1]}")
            echo -e "Getting Access for Storage\n"
            termux-setup-storage
            break
            ;;
        "${options[2]}")
            echo -e "Configuring Git and SSH Key\n"
            configure_git_and_ssh_keys
            break
            ;;
        "${options[3]}")
            echo -e "Cloning Obsidian Git Repo\n"
            clone_obsidian_repo
            break
            ;;
        "${options[4]}")
            echo -e "Optimize repository for obsidian mobile\n"
            optimize_repo_for_mobile
            break
            ;;
        "${options[5]}")
            echo -e "Creating Alias and git commit scripts\n"
            create_alias_and_git_scripts
            break
            ;;
        "${options[6]}")
            exit 0
            ;;
        *) echo "Invalid option" ;;
    esac
done

echo "-------------------------------------------------------"
done
