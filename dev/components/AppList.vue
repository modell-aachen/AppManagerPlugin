<template>
    <div class="flatskin-wrapped">
        <div class="row">
            <div class="column">
            <table class="ma-table .striped">
                <tr v-for="app in apps" v-on:click="getDetails(app.id)">
                    <td>
                        <a href="#">{{ app.name }}</a>
                    </td>
                </tr>
            </table>
            </div>
            <div class="column">
                <app-details v-if="details" :app="appDetails"></app-details>
            </div>
        </div>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'
import AppDetails from './AppDetails.vue'
export default {
    components: {
        AppDetails
    },
    data : function () {
       return {
           details: false,
           appDetails: '',
           apps: []
       }
    },
    methods: {
        getDetails: function(id) {
            this.appDetails = id;
            this.details = true;
        }
    },
    created: function() {
        $( document ).ajaxError(function( event, request, settings, thrownError ) {
                window.console && console.log(request);
                window.console && console.log(settings);
                window.console && console.log(thrownError);
                swal("Request failed!", thrownError, "error");
        });
        NProgress.configure({ showSpinner: false });
        NProgress.start();
        self = this;
        this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/applist?version=1")
        .done( function(result) {
            result = JSON.parse(result);
            console.log(result);
            self.apps = result;
            NProgress.done();
        })
        .fail( function(xhr, status, error) {
            alert("Error get Data!");
            NProgress.done();
        })
    }
}
</script>

<style lang="sass">
.sweet-alert {
    h2 {
        border-style: none;
    }
    hr {
        background-color: transparent;
    }
}
</style>
