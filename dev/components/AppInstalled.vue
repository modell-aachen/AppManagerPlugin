<template>
    <div v-show="ready">
        <template v-if="installed.length!=0">
            <p>This app is currently installed in the following Webs:</p>
            <table class="ma-table .striped">
                <tr v-for="app in installed">
                    <td>
                        {{ app.webName }}
                    </td>
                    <td class="right">
                        <button class="button alert" v-on:click="uninstallApp(app.webName)">Uninstall</button>
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

export default {
    props: ['installed'],
    data : function () {
       return {
           ready: false,
           empty: true
       }
    },
    methods: {
        uninstallApp: function (app) {
            var parent = this.$parent;
            swal({
                title: "Are you sure?",
                text: "All topics of " + app + " will be moved to the Trash Web.",
                type: "warning",
                showCancelButton: true,
                confirmButtonColor: "#D83314",
                confirmButtonText: "Confirm",
                cancelButtonText: "Cancel",
                closeOnConfirm: false,
                closeOnCancel: true
            },
            function(isConfirm){
                if (isConfirm) {
                    parent.$emit('uninstallApp', app);
                }
            });
        }
    },
    created: function() {
        this.ready = true;
    }
}
</script>

<style lang="sass">
.flatskin-wrapped .ma-table {
    .right {
        text-align: right;
    }    
}

</style>
