# coding UTF-8
# Set the global default log level
SemanticLogger.default_level = :trace

# Log to a file, and use the colorized formatter
#SemanticLogger.add_appender(io: STDOUT)
SemanticLogger.add_appender(file_name: '/dev/stdout', formatter: :color)

logger = SemanticLogger['wlrm_support_bot']