ExUnit.start()

# Configuration Tesla pour utiliser le mock en test
Application.put_env(:tesla, :adapter, Tesla.MockAdapter)
