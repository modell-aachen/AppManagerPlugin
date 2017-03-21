<template>
    <div class="wrapper" v-show="ready">
        <div class="widgetBlockTitle">
            {{ appConfig.appname }}
        </div>
        <div class="widgetBlockContent">
            <div v-html="appConfig.description"></div>
            <app-installed :installed="installed" :appname="appConfig.appname"></app-installed>
            <p>For installation, the following configurations are available:</p>
            <div>
                <template v-for="(config, index) in appConfig.installConfigs">
                    <app-install :config="config" :app="app" :depth="0" :multisite-enabled="multisiteEnabled"></app-install>
                    <hr></hr>
                    <hr></hr>
                </template>
            </div>
        </div>
    </div>
</template>

<script>
/* global $ */
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import AppInstall from './AppInstall.vue'
import AppInstalled from './AppInstalled.vue'

export default {
    props: ['app','multisiteEnabled'],
    components: {
        AppInstalled,
        AppInstall
    },
    data : function () {
       return {
           appConfig: '',
           installed: [],
           ready: false
       }
    },
    methods: {
        loadDetails: function() {
            var self = this;
            NProgress.start();
            $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appdetail?name=" + this.app)
            .done( function(result) {
                try{
                    var infos = JSON.parse(result);
                }catch(e){
                    swal("App JSON invalid!", String(e), "error");
                    NProgress.done();
                    return
                }
                self.appConfig = infos.appConfig;
                self.installed = infos.installed;
                self.ready = true;
                NProgress.done();
            })
            .fail( function(xhr, status, error) {
                NProgress.done();
            });
        }
    },
    created: function() {
        this.loadDetails();
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
