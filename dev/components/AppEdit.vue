<template>
    <div class="wrapper" v-show="ready">
        Installname
        <input type="text" v-model="config.destinationWeb"/>
        <template v-if="false">
            <p>The following forms will be installed:</p>
            <div>
            <table class="ma-table">
                <thead><tr><th>Form Name</th><th>Form Group</th></tr></thead>
                <tbody>
                    <tr v-for="action in config.installActions">
                        <template v-if='action.action=="createForm"'>
                            <td><input type="text" v-model="action.formName"/></td>
                            <td><input type="text" v-model="action.formGroup"/></td>
                        </template>                
                    </tr>
                <tbody>
            </table>
            </div>
        </template>
        <input type="checkbox" id="expertcheckbox" v-model="expert"/>
        <label for="expertcheckbox">Expert</label>
        <template v-if="expert">
            <p>
                <textarea rows="16" v-model="configAsJson" v-on:input="validateJson()"></textarea>
            </p>
            <p v-if="invalidJson" id="errorMessage">
                {{ errorMessage }}
            </p>
        </template>
        <p>
            <button class="button primary" v-on:click="customInstall()" v-bind:disabled="invalidJson" title="Install the app using this configuration">Install</button>
            <button class="button alert" v-on:click="abort()" title="Discard changes">Abort</button>
        </p>
    </div>
</template>

<script>

export default {
    props: ['config'],
    data: function () {
       return {
           ready: false,
           expert: false,
           configAsJson: "",
           hasCreateFormActions: false,
           invalidJson: false,
           errorMessage: ""
       }
    },
    methods: {
        abort: function () {
            this.$parent.$emit('reload');
        },
        customInstall: function() {
            this.$parent.$emit('customInstall', this.config);
        },
        validateJson: function() {
            try {
                var customConfig = JSON.parse(this.configAsJson);
                this.config = customConfig; // causes vue warning
                this.errorMessage = "";
                this.invalidJson = false;
            }
            catch(e) {
                window.console && console.log(e.message);               
                window.console && console.log(e.name);
                this.errorMessage = e.message;                 
                this.invalidJson = true;           
            }
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
        // make a json string out of the config object
        this.configAsJson = JSON.stringify(this.config, null, '  ');
        this.ready = true;
    }
}
</script>

<style lang="sass">
    .flatskin-wrapped {
        .redBorder {
            border: 2px red solid;
        }
    }
    #errorMessage {
        color: red;
    }
</style>
