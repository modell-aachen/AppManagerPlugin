<template>
    <div>
        <div class="row align-justify">
            <div
                v-if="depth > 0"
                class="small-1 columns" />
            <div class="columns">
                <h3>{{ config.name }}</h3>
            </div>
            <div class="small-6 columns right">
                <template v-if="!edit">
                    <template v-if="isInstallAllowed">
                        <button
                            class="button primary"
                            @click="install(config)">
                            Install
                        </button>
                        <div class="spacer" />
                        <button
                            v-if="!hasSubConfigs(config)"
                            class="button"
                            title="Click to customize this configuration"
                            @click="editInstall">
                            Edit
                        </button>
                    </template>
                    <template v-else>
                        <p v-if="!isInstallAllowed">
                            Enable multisite to perform this installation.
                        </p>
                    </template>
                </template>
                <template v-else>
                    Installname
                    <input
                        v-model="installName"
                        type="text">
                    <input
                        :id="'expertCheckbox_' + config.name"
                        v-model="expert"
                        type="checkbox">
                    <label :for="'expertCheckbox_' + config.name">Expert</label>
                    <template v-if="expert">
                        <p>
                            <textarea
                                v-model="configJson"
                                rows="16"
                                @input="validateJson()" />
                        </p>
                        <p
                            v-if="invalidJson"
                            class="ma-notification ma-failure">
                            {{ errorMessage }}
                        </p>
                    </template>
                    <p />
                    <button
                        class="button primary"
                        :disabled="invalidJson"
                        title="Install the app using this configuration"
                        @click="installCustom()">
                        Install
                    </button>
                    <div class="spacer" />
                    <button
                        class="button alert"
                        title="Discard changes"
                        @click="abort()">
                        Abort
                    </button>
                </template>
            </div>
        </div>
        <hr>
        <div
            v-if="hasSubConfigs(config) && isInstallAllowed">
            <template v-for="subConfig in config.subConfigs">
                <app-install
                    :key="subConfig.name"
                    :config="subConfig"
                    :app="app"
                    :depth="nextDepth"
                    :multisite-enabled="multisiteEnabled" />
                <hr :key="subConfig.name">
            </template>
        </div>
    </div>
</template>

<script>
/* global $ swal foswiki */
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';

export default {
    props: {
        config: {
            type: Object,
            default: () => {},
        },
        app: {
            type: String,
            default: '',
        },
        depth: {
            type: Number,
            default: 0,
        },
        multisiteEnabled: {
            type: Boolean,
            default: false,
        },
    },
    data: function () {
        return {
            edit: false,
            expert: false,
            configJson: '',
            localConfig: '',
            invalidJson: false,
            errorMessage: '',
        };
    },
    computed: {
        nextDepth: function () {
            return this.depth + 1;
        },
        installName: {
            get: function() {
                return this.localConfig.destinationWeb;
            },
            set: function(input) {
                if(!this.invalidJson) {
                    this.localConfig.destinationWeb = input;
                    this.configJson = JSON.stringify(this.localConfig, null, 4);
                }
            },
        },
        isInstallAllowed: function(){
            return (this.config.name !== 'Multisite' || this.multisiteEnabled);
        },
    },
    created: function() {
        this.configJson = JSON.stringify(this.config, null, 4);
        this.localConfig = $.extend({}, this.config);
        this.ready = true;
        this.$watch('config', function() {
            this.abort();
        });
    },
    beforeCreate: function() {
        this.$options.components.AppInstall = require('./AppInstall.vue');
    },
    methods: {
        abort: function () {
            this.configJson = JSON.stringify(this.config, null, 4);
            this.localConfig = this.config;
            this.expert = false;
            this.invalidJson = false;
            this.edit = false;
        },
        install: function(config) {
            let self = this;
            if(this.request) {
                return false;
            }
            NProgress.start();
            let requestData = {
                appId: this.app,
                installConfig: JSON.stringify(config),
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + '/rest/AppManagerPlugin/appaction',
                requestData)
                .done(function(result) {
                    result = JSON.parse(result);
                    if(result.success === 'warning'){
                        swal('Installation Warning!', result.message, 'warning');
                    }else if(result.success) {
                        let message = 'App installed as ';
                        if(config.subConfigs) {
                            for (let i = 0; i < config.subConfigs.length; i++) {
                                message += config.subConfigs[i].destinationWeb;
                                if(i !== config.subConfigs.length - 1){
                                    message += ' and ';
                                } else {
                                    message += '.';
                                }
                            }
                        }else{
                            message += config.destinationWeb + '.';
                        }
                        swal('Installation Completed!', message, 'success');
                        $.get(foswiki.getScriptUrl('rest', 'FormGeneratorPlugin', 'index'), { mode: 'nosolr' });
                    } else {
                        swal('Installation Failed!', result.message, 'error');
                    }
                    NProgress.done();
                    self.request = null;
                    self.$parent.loadDetails();
                })
                .fail(function() {
                    NProgress.done();
                    self.request = null;
                });
        },
        installCustom: function() {
            this.install(JSON.parse(this.configJson));
        },
        validateJson: function() {
            try {
                this.localConfig = JSON.parse(this.configJson);
                this.errorMessage = '';
                this.invalidJson = false;
            } catch(e) {
                this.errorMessage = e.message;
                this.invalidJson = true;
            }
        },
        hasSubConfigs: function(config) {
            return config.hasOwnProperty('subConfigs');
        },
        editInstall: function() {
            this.edit = true;
        },
    },
};
</script>

<style lang="scss">
.spacer {
    display: inline;
    margin-right: 4px;
}
</style>
