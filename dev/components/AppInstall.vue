<template>
    <div>
    <div class="row align-justify">
        <div class="columns">
            <h3>{{config.name}}</h3>
        </div>
        <div  class="columns right">
            <template v-if="!edit">
                <button class="button primary" v-on:click="install(config)">Install</button>
                <button v-if="!hasSubConfigs(config)" class="button" v-on:click="editInstall" title="Click to customize this configuration">Edit</button>
            </template>
            <template v-else>
                Installname
                <input type="text" v-model="installName"/>
                <input type="checkbox" :id="'expertCheckbox_' + config.name" v-model="expert"/>
                <label :for="'expertCheckbox_' + config.name">Expert</label>
                <template v-if="expert">
                    <p>
                    <textarea rows="16" v-model="configJson" v-on:input="validateJson()"></textarea>
                    </p>
                    <p v-if="invalidJson" class="ma-notification ma-failure">
                    {{ errorMessage }}
                    </p>
                </template>
                <p>
                <button class="button primary" v-on:click="install()" v-bind:disabled="invalidJson" title="Install the app using this configuration">Install</button>
                <button class="button alert" v-on:click="abort()" title="Discard changes">Abort</button>
                </p>
            </template>
        </div>
    </div>
    <template v-if="hasSubConfigs(config)">
        <div class="row align-justify" v-for="subConfig in config.subConfigs">
            <div class="small-1 columns">
            </div>
            <div class="columns">
                <app-install :config="subConfig" :app="app" :index="index++"></app-install>
            </div>
        </div>
    </template>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'

export default {
    props: ['config', 'app', 'index'],
    data: function () {
       return {
           edit: false,
           expert: false,
           configJson: "",
           localConfig: "",
           invalidJson: false,
           errorMessage: ""
       }
    },
    computed: {
        installName: {
            get: function() {
                return this.localConfig.destinationWeb;
            },
            set: function(input) {
                if(!this.invalidJson) {
                    this.localConfig.destinationWeb = input;
                    this.configJson = JSON.stringify(this.localConfig, null, '    ');
                }
            }
        }
    },
    methods: {
        abort: function () {
            this.configJson = JSON.stringify(this.config, null, '    ');
            this.localConfig = this.config;
            this.expert = false;
            this.invalidJson = false;
            this.edit = false;
        },
        install: function(config) {
            self = this;
            if( this.request ) {
                return false;
            }
            NProgress.start();
            var requestData = {
                    version: "1",
                    appId: this.app,
                    installConfig: JSON.stringify(config)
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appaction",
            requestData)
            .done( function(result) {
                result = JSON.parse(result);
                if(result.success) {
                    swal("Installation Completed!",
                    "App installed as " + config.destinationWeb + ".",
                    "success");
                } else {
                    swal("Installation Failed!", result.message, "error");
                }
                NProgress.done();
                self.request = null;
                self.loadDetails();
            })
            .fail( function(xhr, status, error) {
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
                this.errorMessage = "";
                this.invalidJson = false;
            }
            catch(e) {
                this.errorMessage = e.message;
                this.invalidJson = true;
            }
        },
        hasSubConfigs: function(config) {
            return config.hasOwnProperty("subConfigs");
        },
        editInstall: function() {
            this.edit = true;
        }
    },
    created: function() {
        this.configJson = JSON.stringify(this.config, null, '    ');
        this.localConfig = $.extend({}, this.config);
        this.ready = true;
        this.$watch("config", function(newVal, oldVal) {
            this.abort();
        });
    },
    beforeCreate: function() {
        this.$options.components.AppInstall = require('./AppInstall.vue');
    }
}
</script>

<style lang="sass">
</style>
