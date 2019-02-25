PROJECT = emqx_ct_helpers
PROJECT_DESCRIPTION = EMQ X Common Test Helpers
PROJECT_VERSION = 0.1.1

DEPS = meck proper
dep_meck = git https://github.com/emqx/meck.git
dep_proper = git https://github.com/proper-testing/proper.git

BUILD_DEPS = emqx
dep_emqx = git https://github.com/emqtt/emqttd emqx30

include erlang.mk
