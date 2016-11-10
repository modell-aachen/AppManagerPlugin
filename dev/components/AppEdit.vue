<template>
    <div class="wrapper" v-show="ready">
        Installname: <input type="text" v-model="config.destinationWeb"/>
        <button class="button primary" v-on:click="customInstall()">Install</button>
        <button class="button alert" v-on:click="abort()">Abort</button>
    </div>
</template>

<script>

export default {
    props: ['config'],
    data : function () {
       return {
           ready: false
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
        this.ready = true;
    }
}
</script>

<style lang="sass">
</style>
