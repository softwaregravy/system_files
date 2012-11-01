
if [ -x /usr/libexec/path_helper ]; then
      eval `/usr/libexec/path_helper -s`
fi

# Maven 
export M2_HOME=/Applications/apache-maven-3.0.4
export MVN_HOME=$M2_HOME
export M3=$M2_HOME/bin
# optional
#export MAVEN_OPTS="-Xms256m -Xmx512m"

# http://aws.amazon.com/developertools/2928
export AWS_CREDENTIAL_FILE=~/aws-credential-file
export AWS_HOME=/workspace/aws
# Tools expect EC2_HOME
export EC2_HOME=$AWS_HOME/ec2-api-tools-1.5.0.0
export AWS_CF_HOME=$AWS_HOME/AWSCloudFormation-1.0.9
export AWS_ELASTICACHE_HOME=$AWS_HOME/AmazonElastiCacheCli-1.5.000
export AWS_AUTO_SCALING_HOME=$AWS_HOME/AutoScaling-1.0.39.0
export AWS_CW_HOME=$AWS_HOME/CloudWatch-1.0.12.1
export AWS_CLOUDWATCH_HOME=$AWS_CW_HOME
export AWS_ELB_HOME=$AWS_HOME/ElasticLoadBalancing-1.0.17.0
export AWS_IAM_HOME=$AWS_HOME/IAMCli-1.3.0
export AWS_RDS_HOME=$AWS_HOME/RDSCli-1.4.007
export AWS_SNS_HOME=$AWS_HOME/SimpleNotificationServiceCli-1.0.2.3
export AWS_EB_HOME=$AWS_HOME/AWS-ElasticBeanstalk-CLI-2.2/api
export AWS_MAP_REDUCE_HOME=$AWS_HOME/elastic-mapreduce-ruby
export AWS_BINS=$EC2_HOME/bin:$AWS_CF_HOME/bin:$AWS_ELASTICACHE_HOME/bin:$AWS_AUTO_SCALING_HOME/bin:$AWS_CW_HOME/bin:$AWS_ELB_HOME/bin:$AWS_IAM_HOME/bin:$AWS_RDS_HOME/bin:$AWS_EB_HOME/bin:$AWS_MAP_REDUCE_HOME:$AWS_SNS_HOME/bin

export EC2_PRIVATE_KEY=~/.ec2/pk-VT7N5RIWQP4DQ7LXY7D2PBTSEOW23XOR.pem
export EC2_CERT=~/.ec2/cert-VT7N5RIWQP4DQ7LXY7D2PBTSEOW23XOR.pem
export TIMKAY_AWS_HOME=/workspace/aws/com.timkay

export ANT_HOME=/Users/MacbookPro/libs/apache-ant-1.8.2
export JAVA_HOME=/Library/Java/Home

export HADOOP_HOME=/workspace/hadoop
export HIVE_HOME=/workspace/hive
#
# $ ec2-describe-regions                                                                                                                                                                                                                  ──(Mon,Nov14)─┘
# REGION eu-west-1 ec2.eu-west-1.amazonaws.com
# REGION us-east-1 ec2.us-east-1.amazonaws.com
# REGION ap-northeast-1  ec2.ap-northeast-1.amazonaws.com
# REGION us-west-2 ec2.us-west-2.amazonaws.com
# REGION us-west-1 ec2.us-west-1.amazonaws.com
# REGION ap-southeast-1  ec2.ap-southeast-1.amazonaws.com
#
# export EC2_URL=https://<service_endpoint>
#

export PATH=/usr/local/bin:~/scala/bin:/usr/local/sbin:/usr/local/mysql/bin:/opt/local/bin:$PATH:/Library/PostgreSQL/9.0/bin:$ANT_HOME/bin:$AWS_BINS:$TIMKAY_AWS_HOME:$M3:$HADOOP_HOME/bin:$HIVE_HOME/bin:~/bin
#     ~/bin                               \
#     ~/usr/bin                           \
#     /usr/local/bin                      \
#     /usr/bin                            \
#     /bin                                \
#     /usr/sbin                           \
#     /sbin                               \
#     /usr/local/sbin                     \
#     /usr/X11R6/bin                      \
#     /usr/X11/bin                        \
#     /usr/kerberos/bin                   \
#     /opt/local/bin                      \
#     $PATH
#   )

# for running tomcat locally
export CATALINA_OPTS="-Xms512M -Xmx3G"

echo "path is now $PATH"
autoload colors
colors

DIRSTACKSIZE=20   # number of directories in your pushd/popd stack

#vi is better than emacs, and vim is even better
PREFERRED_EDITOR=vim
export EDITOR="$PREFERRED_EDITOR"
export VISUAL="$EDITOR" # I guess some programs use this instead of EDITOR
export PAGER=less

export LESS='-i' # case insensitive matching

# env variable recognizable by .irbrc
# causes rspec to run in development
#export RAILS_ENV="development"

#make grep colorful, always
alias grep='nocorrect grep --color=auto'
#make top look for cpu-hogging processes
alias top='top -o cpu'

# make ls colorful
# osx uses G for colors (I guess)
#alias ls='ls --color=auto'
alias ls='ls -G'

# help me be lazy
alias l='ls'
alias ll='ls -alh'

# use pg to search for programs (poor mans pgrep)
alias pg='ps auxwww | grep '

# use vi on the commandline
bindkey -v
KEYTIMEOUT=1 #helps vi editing mode behave better

# general zsh options
setopt ALWAYS_TO_END      # when something is autocompleted, cursor to end of line
setopt AUTO_NAME_DIRS     # use named dirs when possible
setopt AUTO_PUSHD         # make cd work like pushd (useful for going back x directories with popd)
setopt NO_BEEP            # hate the beep
setopt AUTO_CD            # just type dir vs cd dir
setopt PUSHD_IGNORE_DUPS  # only put unique directories on the pushd stack
setopt RM_STAR_WAIT       # enforces a 10 second wait if you do a rm with a * in it


# history options
setopt EXTENDED_HISTORY        # saves beginning and ending timestamps to the history file
setopt HIST_EXPIRE_DUPS_FIRST  # assuming self-explanatory, but not sure
setopt HIST_VERIFY             # make history commands (subs the command into the line buffer before executing)
setopt INC_APPEND_HISTORY      # each zsh session appends to history file, allow parallel zsh to share one history, entries are appended immediately
HISTSIZE=20000
SAVEHIST=15000
HISTFILE=~/.history
bindkey '^R' history-incremental-search-backward

# The following lines were added by compinstall

zstyle ':completion:*' completer _complete _approximate _expand
# case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# Don't prompt for a huge list, page it!
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
# Don't prompt for a huge list, menu it!
zstyle ':completion:*:default' menu 'select=0'
# Have the newer files last so I see them first
zstyle ':completion:*' file-sort modification revers
# color code completion!!!!  Wohoo!
zstyle ':completion:*' list-colors "=(#b) #([0-9]#)*=36=31"
# Separate man page sections.  Neat.
zstyle ':completion:*:manuals' separate-sections true

zstyle ':completion:*' max-errors 2
zstyle :compinstall filename '/home/johnhin/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

PS1="%{${fg[red]}%}%B%n@%m] %b%{${fg[default]}%}"
RPROMPT="%{${fg[red]}%}%B%-%b%{${fg[default]}%}"

# "u 3" will resolve to cd ../../../
# very handy for deeply nested directories
u ()
{
  ud=".";
  for i ( `seq 1 ${1-1}` ) {
      ud="${ud}/..";
  }
  cd $ud;
}

# I always ls when entering a new directory
chpwd ()
{
  ls;
}

# simply creates a copy of the file with .bk affixed
bk ()
{
  `cp ${1-1} ${1-1}.bk`
}

# swap 2 files 
swap () 
{
  `mv $1 /tmp/$1.tempswapfile`
  `mv $2 $1`
  `mv /tmp/$1.tempswapfile $2`
}


# open firefox, not tied to current term
alias ff='nohup firefox&'


#################### coloring matters ########################
# Color codes: 00;{30,31,32,33,34,35,36,37} and 01;{30,31,32,33,34,35,36,37}
# are actually just color palette items (1-16 in gnome-terminal profile)
# your pallette might be very different from color names given at (http://man.he.net/man1/ls)
# The same LS_COLORS is used for auto-completion via zstyle setting (in this file)
#http://linux-sxs.org/housekeeping/lscolors.html
#
export LSCOLORS=exfxcxdxbxexexabagacad
#export LS_COLORS_BOLD='no=00:fi=00:di=;34:ln=01;95:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.tex=01;33:*.sxw=01;33:*.sxc=01;33:*.lyx=01;33:*.pdf=0;35:*.ps=00;36:*.asm=1;33:*.S=0;33:*.s=0;33:*.h=0;31:*.c=0;35:*.cxx=0;35:*.cc=0;35:*.C=0;35:*.o=1;30:*.am=1;33:*.py=0;34:'
#export LS_COLORS_NORM='no=00:fi=00:di=00;34:ln=00;36:pi=40;33:so=00;35:do=00;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=00;32:*.tar=00;31:*.tgz=00;31:*.arj=00;31:*.taz=00;31:*.lzh=00;31:*.zip=00;31:*.z=00;31:*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.deb=00;31:*.rpm=00;31:*.jar=00;31:*.jpg=00;35:*.jpeg=00;35:*.gif=00;35:*.bmp=00;35:*.pbm=00;35:*.pgm=00;35:*.ppm=00;35:*.tga=00;35:*.xbm=00;35:*.xpm=00;35:*.tif=00;35:*.tiff=00;35:*.png=00;35:*.mpg=00;35:*.mpeg=00;35:*.avi=00;35:*.fli=00;35:*.gl=00;35:*.dl=00;35:*.xcf=00;35:*.xwd=00;35:*.ogg=00;35:*.mp3=00;35:*.wav=00;35:*.tex=00;33:*.sxw=00;33:*.sxc=00;33:*.lyx=00;33:*.pdf=0;35:*.ps=00;36:*.asm=0;33:*.S=0;33:*.s=0;33:*.h=0;31:*.c=0;35:*.cxx=0;35:*.cc=0;35:*.C=0;35:*.o=0;30:*.am=0;33:*.py=0;34:'
#export MY_LS_COLORS="${MY_LS_COLORS:-LS_COLORS_BOLD}"
#eval export LS_COLORS=\${$MY_LS_COLORS}


#rvm installation
#http://rvm.beginrescueend.com/
#[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
source /usr/local/rvm/scripts/rvm
rvm_project_rvmrc_default=1

export AUTOFEATURE=true 
export RSPEC=true

# anyone else want a better migrate?
# http://blog.voxdolo.me/twiki.html
twiki () {
  # say -v Zarvox 'beedee-beedee-beedee'
  rake db:migrate && rake db:migrate:redo && rake db:test:prepare
}

timestamp() {
  date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s"
}

# ssh into beanstalk
sshb() {
  ssh -i ~/culver_keys.pem ec2-user@$(elastic-beanstalk-describe-environments -a $1 --no-header | grep Green | cut -f 7 -d "|" | xargs -I {} elastic-beanstalk-describe-environment-resources -E {} --no-header | head -n1 | cut -f 3 -d "|" | xargs ec2-describe-instances | grep INSTANCE | cut -f 4 )
}

# ls aws beanstalk
lsb() {
  elastic-beanstalk-describe-environments -a $1 --no-header | grep Green | cut -f 7 -d "|" | xargs -I {} elastic-beanstalk-describe-environment-resources -E {} --no-header | head -n1 | cut -f 3 -d "|" | tr -d "," | xargs ec2-describe-instances | grep INSTANCE | cut -f 2,4,5
}

alias cucumber='cucumber --require features --require lib'
# ssh into a venice sandbox host Note: requires John's custom modifications the ebs scripts to suppress headers (the --no-header option is not standard)
alias sshvsb='ssh -i ~/culver_keys.pem ec2-user@$(elastic-beanstalk-describe-environments -a venice-sandbox --no-header | grep Green | cut -f 7 -d "|" | xargs -I {} elastic-beanstalk-describe-environment-resources -E {} --no-header | head -n1 | cut -f 3 -d "|" | tr "," "\n" | head -n1 | xargs ec2-describe-instances | grep INSTANCE | cut -f 4 )' 
alias sshvt='ssh -i ~/culver_keys.pem ec2-user@$(elastic-beanstalk-describe-environments -a venice-test --no-header | grep Green | cut -f 7 -d "|" | xargs -I {} elastic-beanstalk-describe-environment-resources -E {} --no-header | head -n1 | cut -f 3 -d "|" | tr "," "\n" | head -n1 | xargs ec2-describe-instances | grep INSTANCE | cut -f 4 )' 
alias sshvp='ssh -i ~/culver_keys.pem ec2-user@$(elastic-beanstalk-describe-environments -a venice-production --no-header | grep Green | cut -f 7 -d "|" | xargs -I {} elastic-beanstalk-describe-environment-resources -E {} --no-header | head -n1 | cut -f 3 -d "|" | tr "," "\n" | head -n1 | xargs ec2-describe-instances | grep INSTANCE | cut -f 4 )' 
alias lsvsb='lsb venice-sandbox'
alias lsvt='lsb venice-test'
alias lsvp='lsb venice-production'

# Heroku 
alias hls='heroku logs --tail --remote sandbox'
alias hlp='heroku logs --tail --remote production'
alias hcs='heroku run console --remote sandbox'
alias hcp='heroku run console --remote production'

alias cdtomcat='cd /usr/local/Cellar/tomcat/7.0.29/libexec/'

source ~/.zshrc.cmdprompt

export TERM='xterm-256color'

PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
