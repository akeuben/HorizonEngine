Merge SwapchainVulkanRenderTarget into Swapchain
- They are very similar in what they do, and combining them will result in less "sphagetti"

Add shader uniform support
- 

Revamp Object system
- Vulkan does not support VAO's so the object system is in place to allow OpenGL to use this system, but Vulkan
    can just use it as a passthrough of parameters
- Idially, a render object will describe exactly how the object should be rendered (i.e: index vs non-index, triangle list vs strip,
    triangle vs line vs point, etc...)

                                            +-------------------+
                                            |   Render Object   |
                                            +-------------------+
                                            /        |          \
                                           /         |           \
                                          /          |            \
                                         /           |             \
                +------------------------+ +---------------------+ +-------------------------+
                | VertexListRenderObject | | IndexedRenderObject | | Instanced Render Object | ...
                +------------------------+ +---------------------+ +-------------------------+
    Tagged Enum   |      |       |            |      |       |            |      |       |
                +----+ +----+ +------+      +----+ +----+ +------+      +----+ +----+ +------+
                | GL | | VK | | NONE |      | GL | | VK | | NONE |      | GL | | VK | | NONE |
                +----+ +----+ +------+      +----+ +----+ +------+      +----+ +----+ +------+

