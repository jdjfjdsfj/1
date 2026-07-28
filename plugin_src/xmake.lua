add_rules('mode.release', 'mode.debug')

--- global configs

set_languages('cxx23', 'c11')
set_warnings('all')
set_exceptions('cxx')

--- targets

target('clock_plugin')
-- 插件必须编译为动态库 (.so)
set_kind('shared')
add_rules('qt.shared')

-- 源代码
add_files('src/*.cpp')
add_files('src/*.h')

-- 插件需要的 Qt 组件
add_frameworks(
    'QtCore',
    'QtQuick',
    'QtQml')
