# =============================================================================
# config.rb -- CHIFIG::CONFIG
#
# Copyright
#
# LICENSE
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
