import toolchain

fake_metadata = {
    'a': {
        '0.1': {}
    },
    'b': {
        '0.2': {
            'dependencies': ['a=0.1']
        }
    },
    'c': {
        '0.3': {
            'dependencies': ['a=0.1', 'b=0.2']
        }
    },
    'd': {
        '0.4': {
            'dependencies': ['b=0.2']
        }
    },
}


def test_build_ordering():
    libs = ['a=0.1', 'd=0.4']
    builder = toolchain.ScriptBuilder(libs, package_registry=fake_metadata)
    result = builder.get_build_script()
    expected = toolchain.BUILD_SCRIPT_PREAMBLE + """\
A_VERSION=0.1 $SOURCE_DIR/source/a/build.sh
A_VERSION=0.1 B_VERSION=0.2 $SOURCE_DIR/source/b/build.sh
B_VERSION=0.2 D_VERSION=0.4 $SOURCE_DIR/source/d/build.sh"""

    assert result == expected

    libs = ['d=0.4']
    builder = toolchain.ScriptBuilder(libs, package_registry=fake_metadata)
    result = builder.get_build_script()
    expected = toolchain.BUILD_SCRIPT_PREAMBLE + """\
A_VERSION=0.1 $SOURCE_DIR/source/a/build.sh
A_VERSION=0.1 B_VERSION=0.2 $SOURCE_DIR/source/b/build.sh
B_VERSION=0.2 D_VERSION=0.4 $SOURCE_DIR/source/d/build.sh"""

    assert result == expected
