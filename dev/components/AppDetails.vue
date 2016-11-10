<template>
    <div class="wrapper" v-show="ready">
        <div class="widgetBlockTitle">
        {{ appConfig.appname }}
        </div>
        <div class="widgetBlockContent">
            <p>{{ appConfig.description }}</p>
            <app-installed :installed="installed"></app-installed>
            <table class="ma-table">
                <tr v-for="config in appConfig.installConfigs">
                    <td class="top"><h3>{{config.name}}</h3></td>
                    <td>
                        <template v-if="!edit">
                            <button class="button primary" v-on:click="installApp(config)">Install</button>
                            <button class="button" v-on:click="editInstall(config)">Edit</button>
                        </template>
                        <template v-else>
                            <app-edit :config="config"></app-edit>
                        </template>
                    </td>
                </tr>
            </table>
        </div>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'
import AppEdit from './AppEdit.vue'
import AppInstalled from './AppInstalled.vue'

export default {
    props: ['app'],
    components: {
        AppEdit,
        AppInstalled
    },
    data : function () {
       return {
           appConfig: '',
           installed: [],
           config: '',
           edit: false,
           ready: false
       }
    },
    methods: {
        editInstall: function(config) {
            this.config = config;
            this.edit = true;
        },
        installApp: function(action) {
            self = this;
            if( this.request ) {
                return false;
            }
            NProgress.start();
            var requestData = {
                    version: "1",
                    appId: this.app,
                    installConfig: JSON.stringify(action)
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appaction",
            requestData)
            .done( function(result) {
                result = JSON.parse(result);
                if(result.success) {
                    swal("Installation Completed!",
                    "App installed as " + action.destinationWeb + ".",
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
        uninstallApp: function(app) {
            self = this;
            if( this.request ) {
                return false;
            }
            var requestData = {
                    appWeb: app,
                    appName: this.appConfig.appname
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appuninstall",
            requestData)
            .done( function(result) {
                result = JSON.parse(result);
                window.console && window.console.log(result);
                if(result.status == "ok") {
                    swal("Success!",
                    "App uninstalled",
                    "success");
                } else {
                    swal("Uninstallation Failed!", result.message, "error");
                }
                self.loadDetails();
                self.request = null;
            })
            .fail( function(xhr, status, error) {
                self.request = null;
            });
        },
        loadDetails: function() {
            self = this;
            NProgress.start();
            this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appdetail?version=1;name=" + this.app)
            .done( function(result) {
                var infos = JSON.parse(result);
                self.appConfig = infos.appConfig;
                self.installed = infos.installed;
                self.ready = true;
                NProgress.done();
                self.request = null;
            })
            .fail( function(xhr, status, error) {
                NProgress.done();
                self.request = null;
            });
        }
    },
    created: function() {
        this.loadDetails();
        this.$on("reload", function() {
            this.edit = false;
            this.loadDetails();
        });
        this.$on("customInstall", function(action) {
            this.installApp(action);
        });
        this.$on("uninstallApp", function(app) {
            this.uninstallApp(app);
        });
        // is fired whenever the app property changes
        this.$watch("app", function(newVal, oldVal) {
            this.loadDetails();
        })
    }
}
</script>

<style lang="sass">
.flatskin-wrapped {
    .button {
        margin: 0px;
    }
    h3 {
        margin: 0px;
    }
    .top {
        vertical-align: top;
    }
}
</style>
