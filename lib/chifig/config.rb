# =============================================================================
# config.rb -- CHIFIG::CONFIG
#
# Copyright (c) 2019-2020 Benjamin P. Haley
#
# See the LICENSE file for information on usage and redistribution of this
# file and for a DISCLAIMER OF ALL WARRANTIES.
# =============================================================================

module CHIFIG

CONFIG = {}
CONFIG['bindir'] = '@BINDIR@'
CONFIG['datadir'] = '@DATADIR@'
CONFIG['default_json_path'] = File.join(CONFIG['datadir'], 'default.json')
CONFIG['latex_path'] = '@LATEX_PATH@'
CONFIG['dvips_path'] = '@DVIPS_PATH@'
CONFIG['editor_path'] = '@EDITOR_PATH@'
CONFIG['gs_path'] = '@GS_PATH@'

end
