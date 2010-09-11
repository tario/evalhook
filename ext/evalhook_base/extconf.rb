require 'mkmf'
dir_config('evalhook_base')
CONFIG['CC'] = 'gcc'
create_makefile('evalhook_base')



