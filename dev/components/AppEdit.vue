<template>
    <div class="wrapper" v-show="ready">
        Installname: <input type="text" v-model="config.destinationWeb"/>
        <template v-if="hasCreateFormActions">
            The following forms will be installed:
            <table>
                <tr v-for="action in config.installActions">
                    <template v-if='action.action=="createForm"'>
                        <td>Form name:<input type="text" v-model="action.formName"/></td>
                        <td>Form group:<input type="text" v-model="action.formGroup"/></td>
                    </template>                
                </tr>
            </table>
        </template>
        <button class="button primary" v-on:click="customInstall()">Install</button>
        <button class="button alert" v-on:click="abort()">Abort</button>
    </div>
</template>

<script>

export default {
    props: ['config'],
    data : function () {
       return {
           ready: false,
           hasCreateFormActions: false
       }
    },
    methods: {
        abort: function () {
            this.$parent.$emit('reload');
        },
        customInstall: function() {
            this.$parent.$emit('customInstall', this.config);
        }
    },
    created: function() {
        // check if there are any createForm actions in the install config
        for(var i = 0; i < this.config.installActions.length; i++) {
            if(this.config.installActions[i].action == "createForm") {
                this.hasCreateFormActions = true;
                break;
            }
        }
        this.ready = true;
    }
}
</script>

<style lang="sass">
</style>
