<template>
    <div class="flatskin-wrapped">
        <div class="row expanded">
            <div class="shrink column">
            <table class="ma-table .striped">
                <tr v-for="app in apps" v-on:click="getDetails(app.id)">
                    <td>
                        <a href="#">{{ app.name }}</a>
                    </td>
                </tr>
            </table>
            </div>
            <div class="column">
                <app-details v-if="details" :app="appDetails" :multisite-enabled="multisite.enabled"></app-details>
            </div>
        </div>
        <div v-if="multisite.available">
            <div class="cmtBoxTitle">
                <div v-if="!multisite.enabled">
                    <p>Multisite is not enabled: <button class="small button primary" v-on:click="toggleMultisite()">enable</button><p>
                    <p class="ma-notification">A click on enable installs everything needed to make the Wiki multisite-capable (e.g. installing the Settings and OUTemplates web). This will also enable multisite installations for apps.</p>
                </div>
                <div v-else>
                    <p>Multisite is enabled: <button class="button alert" v-on:click="toggleMultisite()">disable</button></p>
                    <p class="ma-notification ma-failure">Disabling multisite will move the Settings and OUTemplate webs to Trash. It will move the CustomWebLeftBar to trash and it will remove multisite settings from SitePreferences</p>
                </div>
            </div>
        </div>
        <div v-else>
            <p class="ma-notification">Multisite installation is not available. To enable multisite make sure that MultisiteAppContrib is installed.</p>
        </div>
    </div>
</template>

<script>
/* global $ swal foswiki */
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';
import AppDetails from './AppDetails.vue';

export default {
    components: {
        AppDetails
    },
    data : function () {
       return {
           details: false,
           appDetails: '',
           multisite: '',
           apps: []
       };
    },
    methods: {
        getAppList: function() {
            NProgress.start();
            let self = this;
            this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/applist")
            .done( function(result) {
                result = JSON.parse(result);
                self.apps = result.apps;
                self.multisite = result.multisite;
                NProgress.done();
            })
            .fail( function() {
                NProgress.done();
            });
        },
        getDetails: function(id) {
            this.appDetails = id;
            this.details = true;
        },
        toggleMultisite: function() {
            NProgress.start();
            let requestData = {
                enable: !this.multisite.enabled,
            };
            let self = this;
            $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/multisite", requestData)
            .done( function(result) {
                let state;
                result = JSON.parse(result);
                if(!self.multisite.enabled) {
                    state = "Activate";
                }else{
                    state = "Deactivate";
                }
                if(result.success) {
                    swal("Success!",
                    state + " Multisite ",
                    "success");
                } else {
                    swal(state + " Multisite failed!", result.message, "error");
                }
                NProgress.done();
                self.getAppList();
            })
            .fail( function() {
                NProgress.done();
            });
        }
    },
    created: function() {
        $( document ).ajaxError(function( event, request, settings, thrownError ) {
                window.console && console.log(request);
                window.console && console.log(settings);
                window.console && console.log(thrownError);
                swal({
                    title: "Request failed!",
                    text: request.responseText,
                    html: true,
                    type: "error"
                });
        });
        NProgress.configure({ showSpinner: false });
        this.getAppList();
    }
};
</script>

<style lang="scss">
.sweet-alert {
    h2 {
        border-style: none;
    }
    hr {
        background-color: transparent;
    }
}
    div .right {
        float: right;
    }
</style>
