<template>
    <div
        v-show="ready"
        class="wrapper">
        <div class="widgetBlockTitle">
            {{ appConfig.appname }}
        </div>
        <div class="widgetBlockContent">
            <!-- eslint-disable-next-line vue/no-v-html -->
            <div v-html="appConfig.description" />
            <app-installed
                :installed="installed"
                :appname="appConfig.appname" />
            <p>For installation, the following configurations are available:</p>
            <div>
                <template
                    v-for="config in appConfig.installConfigs">
                    <app-install
                        :key="config.name"
                        :config="config"
                        :app="app"
                        :depth="0"
                        :multisite-enabled="multisiteEnabled" />
                    <hr :key="config.name">
                    <hr :key="config.name">
                </template>
            </div>
        </div>
    </div>
</template>

<script>
/* global $ swal foswiki */
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';
import AppInstall from './AppInstall.vue';
import AppInstalled from './AppInstalled.vue';

export default {
    components: {
        AppInstalled,
        AppInstall,
    },
    props: {
        app: {
            type: String,
            default: '',
        },
        multisiteEnabled: {
            type: Boolean,
            default: false,
        },
    },
    data: function () {
        return {
            appConfig: '',
            installed: [],
            ready: false,
        };
    },
    created: function() {
        this.loadDetails();
        this.$watch('app', function() {
            this.loadDetails();
        });
    },
    methods: {
        loadDetails: function() {
            let self = this;
            NProgress.start();
            $.get(foswiki.preferences.SCRIPTURL + '/rest/AppManagerPlugin/appdetail?name=' + this.app)
                .done(function(result) {
                    let infos;
                    try{
                        infos = JSON.parse(result);
                    }catch(e){
                        swal('App JSON invalid!', String(e), 'error');
                        NProgress.done();
                        return;
                    }
                    self.appConfig = infos.appConfig;
                    self.installed = infos.installed;
                    self.ready = true;
                    NProgress.done();
                })
                .fail(function() {
                    NProgress.done();
                });
        },
    },
};
</script>

<style lang="scss">
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
