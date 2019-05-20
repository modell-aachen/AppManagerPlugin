<template>
    <div v-show="ready">
        <template v-if="installed.length!=0">
            <p>This app is currently installed in the following Webs:</p>
            <table class="ma-table .striped">
                <tr
                    v-for="app in installed"
                    :key="app.webName">
                    <td>
                        <a :href="linkToWeb(app.webName)">{{ app.webName }}</a>
                    </td>
                    <td class="right">
                        <button
                            class="button alert"
                            @click="uninstallApp(app.webName)">
                            Uninstall
                        </button>
                    </td>
                </tr>
            </table>
        </template>
        <template v-else>
            <p>This app is currently nowhere installed. You can install it using the buttons below.</p>
        </template>
    </div>
</template>

<script>
/* global $ swal foswiki */
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';

export default {
    props: {
        installed: {
            type: Array,
            default: () => [],
        },
        appname: {
            type: String,
            default: '',
        },
    },
    data: function () {
        return {
            ready: false,
            empty: true,
        };
    },
    created: function() {
        this.ready = true;
    },
    methods: {
        uninstallApp: function (app) {
            let self = this;
            swal({
                title: 'Are you sure?',
                text: 'All topics of ' + app + ' will be moved to the Trash Web.',
                type: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#D83314',
                confirmButtonText: 'Confirm',
                cancelButtonText: 'Cancel',
                closeOnConfirm: true,
                closeOnCancel: true,
            },
            function(isConfirm){
                if (isConfirm) {
                    NProgress.start();
                    let requestData = {
                        appWeb: app,
                        appName: self.appname,
                    };
                    $.post(foswiki.preferences.SCRIPTURL + '/rest/AppManagerPlugin/appuninstall', requestData)
                        .done(function(result) {
                            result = JSON.parse(result);
                            if(result.status === 'ok') {
                                swal('Success!',
                                    'App uninstalled',
                                    'success');
                            } else {
                                swal('Uninstallation Failed!', result.message, 'error');
                            }
                            NProgress.done();
                            self.$parent.loadDetails();
                        })
                        .fail(function() {
                            NProgress.done();
                        });
                }
            });
        },
        linkToWeb: function(webName) {
            return foswiki.getScriptUrl() + 'view/' + webName;
        },
    },
};
</script>

<style lang="scss">
.flatskin-wrapped .ma-table {
    .right {
        text-align: right;
    }
}
</style>
