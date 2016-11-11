<template>
    <div class="wrapper" v-show="ready">
        <div class="widgetBlockTitle">
        {{ appConfig.appname }}
        </div>
        <div class="widgetBlockContent">
            <p>{{ appConfig.description }}</p>
            <app-installed :installed="installed"></app-installed>
            <p>For installation, the following configurations are available:</p>
            <table class="ma-table">
                <template v-for="(config, index) in appConfig.installConfigs">
                    <tr>
                        <!-- render config name -->
                        <td class="top">
                            <h3>{{config.name}}</h3>
                        </td>
                        <!-- render buttons or edit component -->
                        <td>
                            <template v-if="!edit[index]">
                                <button class="button primary" v-on:click="installApp(config)">Install</button>
                                <button v-if="!hasSubConfigs(config)" class="button" 
                                    v-on:click="editInstall(index)" title="Click to customize this configuration">Edit</button>
                            </template>
                            <template v-else>
                                <app-edit :config="config" :index="index" :subIndex="-1"></app-edit>
                            </template>
                        </td>
                    </tr>
                    <!-- render sub configs if available -->
                    <template v-if="hasSubConfigs(config)">
                        <tr v-for="(subConfig, subIndex) in config.subConfigs">
                            <td class="top">
                                <h4>{{subConfig.name}}<h4>
                            </td>
                            <!-- render buttons or edit component -->
                            <td>
                                <template v-if="!subEdit[index][subIndex]">
                                    <button class="button primary" v-on:click="installApp(subConfig)">Install</button>
                                    <button class="button" v-on:click="editInstallSub(index, subIndex)" title="Click customize this configuration">Edit</button>
                                </template>
                                <template v-else>
                                    <app-edit :config="subConfig" :index="index" :subIndex="subIndex"></app-edit>
                                </template>
                            </td>
                        </tr>
                    </template>
                </template>
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
           edit: [],
           subEdit: [[]],
           ready: false
       }
    },

    methods: {
        hasSubConfigs: function(config) {
            return config.hasOwnProperty("subConfigs");
        },
        editInstall: function(index) {
            Vue.set(this.edit, index, true);
        },
        editInstallSub: function(index, subIndex) {
            var array = this.subEdit[index];
            array[subIndex] = true;
            Vue.set(this.subEdit, index, array);
        },
        installApp: function(config) {
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
                    this.hasSubConfigs(config) ? "All components installed." : "App installed as " + config.destinationWeb + ".",
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
            NProgress.start();
            var requestData = {
                    appWeb: app,
                    appName: this.appConfig.appname
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appuninstall",
            requestData)
            .done( function(result) {
                result = JSON.parse(result);
                if(result.status == "ok") {
                    swal("Success!",
                    "App uninstalled",
                    "success");
                } else {
                    swal("Uninstallation Failed!", result.message, "error");
                }
                NProgress.done();
                self.loadDetails();
                self.request = null;
            })
            .fail( function(xhr, status, error) {
                NProgress.done();
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
                self.edit = new Array(self.appConfig.installConfigs.length).fill(false);
                self.subEdit = [[]];
                for(var i = 0; i < self.edit.length; i++) {
                    if(self.appConfig.installConfigs[i].hasOwnProperty("subConfigs")) {
                        self.subEdit[i] = new Array(self.appConfig.installConfigs[i].subConfigs.length).fill(false);
                    }
                    else {
                        self.subEdit[i] = [];
                    }
                }
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
        this.$on("abort", function(index, subIndex) {
            Vue.set(this.edit, index, false);
            if(subIndex != -1) {
                var array = this.subEdit[index];
                array[subIndex] = false;
                Vue.set(this.subEdit, index, array);
            }
            //this.loadDetails();
        });
        this.$on("customInstall", function(config) {
            this.installApp(config);
        });
        this.$on("uninstallApp", function(app) {
            this.uninstallApp(app);
        });
        // is fired whenever the app property changes
        this.$watch("app", function(newVal, oldVal) {
            this.loadDetails();
        });
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
    h4 {
        margin: 0px;
        padding-left: 20px;
    }
    .top {
        vertical-align: top;
    }
    .flatskin-wrapped .ma-table {
        .right {
            text-align: right;
        }    
    }
}
</style>
