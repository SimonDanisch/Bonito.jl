<template>
    <div ref="container" v-html="sanitizedContent"></div>
</template>

<script>
import { ref, onMounted } from 'vue'

export default {
props: {
    content: {
    type: String,
    required: true
    }
},
setup(props) {
    const container = ref(null)
    const sanitizedContent = ref('')

    onMounted(() => {
    // Sanitize and process the HTML content
    sanitizedContent.value = props.content
    
    // Execute any scripts after mounting
    nextTick(() => {
        const scripts = container.value.getElementsByTagName('script')
        Array.from(scripts).forEach(script => {
          const newScript = document.createElement('script')
          Array.from(script.attributes).forEach(attr => {
            newScript.setAttribute(attr.name, attr.value)
          })
          newScript.innerHTML = script.innerHTML
          script.parentNode.replaceChild(newScript, script)
        })

        // Initialize Bonito if present
        if (window.Bonito) {
          const fragments = container.value.getElementsByClassName('bonito-fragment')
          Array.from(fragments).forEach(fragment => {
            const id = fragment.getAttribute('id')
            if (id) {
              window.Bonito.init_session(id, null, 'sub', false)
            }
          })
        }
      })
    })

    return {
    container,
    sanitizedContent
    }
}
}
</script>