<template>
    <div class="wrapper" v-show="ready">
        <div class="widgetBlockTitle">
            {{ appConfig.appname }}
        </div>
        <div class="widgetBlockContent">
            <p>{{ appConfig.description }}</p>
            <app-installed :installed="installed" :appname="appConfig.appname"></app-installed>
            <p>For installation, the following configurations are available:</p>
            <div>
                <template v-for="(config, index) in appConfig.installConfigs">
                    <app-install :config="config" :app="app" :depth="0"></app-install>
                    <hr></hr>
                    <hr></hr>
                </template>
            </div>
        </div>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'
import AppInstall from './AppInstall.vue'
import AppInstalled from './AppInstalled.vue'

export default {
    props: ['app'],
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
            self = this;
            NProgress.start();
            $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appdetail?version=1;name=" + this.app)
            .done( function(result) {
                var infos = JSON.parse(result);
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
