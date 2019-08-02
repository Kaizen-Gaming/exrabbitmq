import Config

config :exrabbitmq, :test_different_connections,
  reconnect_after: 500,
  pool: [size: 20, max_overflow: 5]

config :exrabbitmq, :test_max_channels,
  reconnect_after: 500,
  max_channels: 1,
  pool: [size: 2, max_overflow: 1]

config :exrabbitmq, :test_basic_session,
  queue: "queue_a",
  consume_opts: [],
  qos_opts: [],
  declarations: [
    {:queue,
     [
       name: "queue_a",
       opts: [auto_delete: true],
       bindings: []
     ]}
  ]

config :exrabbitmq, :test_session,
  queue: "queue_a",
  consume_opts: [],
  qos_opts: [],
  declarations: [
    {:exchange,
     [
       name: "firstlevelrouting",
       type: :topic,
       opts: []
     ]},
    {:exchange,
     [
       name: "secondlevelrouting",
       type: :topic,
       opts: [],
       bindings: [
         [
           exchange: "firstlevelrouting",
           opts: [routing_key: "#"]
         ]
       ]
     ]},
    {:queue,
     [
       name: "queue_a",
       opts: [],
       bindings: [
         [
           exchange: "foo",
           opts: []
         ]
       ]
     ]}
  ]
