# LangChain Python — Integration Contribution Guide

*Source: https://docs.langchain.com/oss/python/contributing/integrations-langchain*

## Why Contribute Integrations?

LangChain encourages integration development for three main reasons:
- **Discoverability**: 200+ million monthly downloads
- **Interoperability**: Standard interfaces allow easy component swapping
- **Best practices**: Streaming, async support, improved performance

## Recommended Component Types

The framework prioritizes these integrations:
- **Chat Models** (most actively used)
- **Tools/Toolkits** (enable agent capabilities)
- **Retrievers** (essential for RAG)
- **Embedding Models** (support vector operations)
- **Vector Stores** (semantic search foundation)
- **Sandboxes** (safe code execution)

**Not recommended**: Text-completion LLMs, document loaders, key-value stores, document transformers, model caches, graphs, message histories, callbacks, chat loaders, adapters.

## Contribution Steps

1. **Implementation**: Build your integration package following LangChain standards
2. **Testing**: Pass applicable standard test suites
3. **Publication**: Release your integration package
4. **Documentation**: Submit PR with integration docs using provided templates for your component type

Documentation is mandatory — "An integration is only as useful as its documentation." Templates exist for chat models, tools/toolkits, and vector stores.

## Additional Opportunities

Optional co-marketing engagement with the LangChain team is available for published integrations.
