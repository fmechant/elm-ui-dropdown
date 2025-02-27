module Dropdown exposing
    ( State, init
    , Msg
    , Config, basic, filterable, multi
    , withContainerAttributes, withPromptElement, withFilterPlaceholder, withSelectAttributes, withSearchAttributes, withOpenCloseButtons, withListAttributes
    , update, view
    , onOutsideClick
    )

{-| Elm UI Dropdown.

@docs State, init
@docs Msg
@docs Config, basic, filterable, multi
@docs withContainerAttributes, withPromptElement, withFilterPlaceholder, withSelectAttributes, withSearchAttributes, withOpenCloseButtons, withListAttributes
@docs update, view
@docs onOutsideClick

-}

import Browser.Dom as Dom
import Browser.Events exposing (onMouseDown)
import Element exposing (..)
import Element.Events as Events
import Element.Input as Input
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Task


type DropdownType
    = Basic
    | Filterable
    | MultiSelect


type alias InternalState =
    { id : String
    , isOpen : Bool
    , filterText : String
    , focusedIndex : Int
    }


{-| Types that hold the handlers for single and multiple selects. |
-}
type SelectionToPrompt item msg
    = SingleItemToPrompt (item -> Element msg)
    | MultipleItemsToPrompt (List item -> Element msg)


type OnSelectMsg item msg
    = OnSelectSingleItem (Maybe item -> msg)
    | OnSelectMultipleItems (List item -> msg)


type Selection item
    = SingleItem (Maybe item)
    | MultipleItems (List item)


{-| Opaque type that holds the current state

    type alias Model =
        { dropdownState : Dropdown.State
        }

-}
type
    State item
    -- item type parameter is not currently used, but keeping it so if it does ever become needed it doesn't change the public api
    = State InternalState


type alias InternalConfig item msg model =
    { dropdownType : DropdownType
    , itemsFromModel : model -> List item
    , selectionFromModel : model -> Selection item
    , dropdownMsg : Msg item -> msg
    , onSelectMsg : OnSelectMsg item msg
    , selectionToPrompt : SelectionToPrompt item msg
    , promptElement : Element msg
    , itemToElement : Bool -> Bool -> item -> Element msg
    , itemToText : item -> String
    , filterPlaceholder : Maybe String
    , openButton : Element msg
    , closeButton : Element msg
    , containerAttributes : List (Attribute msg)
    , selectAttributes : List (Attribute msg)
    , listAttributes : List (Attribute msg)
    , searchAttributes : List (Attribute msg)
    }


{-| Opaque type that holds the current config

    dropdownConfig =
        Dropdown.basic
            { allItems = always [ "apples", "bananas", "oranges" ]
            , selectedItem = .selectedFruit
            , dropdownMsg = DropdownMsg
            , onSelectMsg = FruitPicked
            , itemToPrompt = Element.text
            , itemToElement = \selected -> \highlighted -> Element.text
            }

-}
type Config item msg model
    = Config (InternalConfig item msg model)


{-| Opaque type for the internal dropdown messages
-}
type Msg item
    = NoOp
    | OnBlur
    | OnClickPrompt
    | OnSelect item
    | OnFilterTyped String
    | OnKeyDown Key
    | OnClickOutside


type Key
    = ArrowDown
    | ArrowUp
    | Enter
    | Esc


{-| Create a new state. You must pass a unique identifier for each dropdown component.

    {
        ...
        dropdownState = Dropdown.init "country-dropdown"
    }

-}
init : String -> State item
init id =
    State
        { id = id
        , isOpen = False
        , filterText = ""
        , focusedIndex = 0
        }


{-| Create a basic configuration. This takes:

    - itemsFromModel - The list of items to display in the dropdown (as a function of the model)
    - selectionFromModel - The function to get the selected item from the model
    - dropdownMsg - The message to wrap all the internal messages of the dropdown
    - onSelectMsg - A message to trigger when an item is selected
    - itemToPrompt - A function to get the Element to display from an item, to be used in the select part of the dropdown
    - itemToElement - A function that takes a bool for whether the item is selected followed by a bool for whether the item is highlighted, followed by the item and returns the Element to display, to be used in the list part of the dropdown

-}
basic :
    { itemsFromModel : model -> List item
    , selectionFromModel : model -> Maybe item
    , dropdownMsg : Msg item -> msg
    , onSelectMsg : Maybe item -> msg
    , itemToPrompt : item -> Element msg
    , itemToElement : Bool -> Bool -> item -> Element msg
    }
    -> Config item msg model
basic { itemsFromModel, selectionFromModel, dropdownMsg, onSelectMsg, itemToPrompt, itemToElement } =
    Config
        { dropdownType = Basic
        , itemsFromModel = itemsFromModel
        , selectionFromModel = selectionFromModel >> SingleItem
        , dropdownMsg = dropdownMsg
        , onSelectMsg = OnSelectSingleItem onSelectMsg
        , selectionToPrompt = SingleItemToPrompt itemToPrompt
        , promptElement = el [ width fill ] (text "-- Select --")
        , itemToElement = itemToElement
        , itemToText = \_ -> ""
        , filterPlaceholder = Nothing
        , openButton = text "▼"
        , closeButton = text "▲"
        , containerAttributes = []
        , listAttributes = []
        , searchAttributes = []
        , selectAttributes = []
        }


{-| Create a multiselect configuration. This takes:

    - itemsFromModel - The list of items to display in the dropdown (as a function of the model)
    - selectionFromModel - The function to get the selected items from the model
    - dropdownMsg - The message to wrap all the internal messages of the dropdown
    - onSelectMsg - A message to trigger when an item is selected
    - itemsToPrompt - A function to get the Element to display from the list of selected items, to be used in the select part of the dropdown
    - itemToElement - A function that takes a bool for whether the item is selected followed by a bool for whether the item is highlighted, followed by the item and returns the Element to display, to be used in the list part of the dropdown

-}
multi :
    { itemsFromModel : model -> List item
    , selectionFromModel : model -> List item
    , dropdownMsg : Msg item -> msg
    , onSelectMsg : List item -> msg
    , itemsToPrompt : List item -> Element msg
    , itemToElement : Bool -> Bool -> item -> Element msg
    }
    -> Config item msg model
multi { itemsFromModel, selectionFromModel, dropdownMsg, onSelectMsg, itemsToPrompt, itemToElement } =
    Config
        { dropdownType = MultiSelect
        , itemsFromModel = itemsFromModel
        , selectionFromModel = selectionFromModel >> MultipleItems
        , dropdownMsg = dropdownMsg
        , onSelectMsg = OnSelectMultipleItems onSelectMsg
        , selectionToPrompt = MultipleItemsToPrompt itemsToPrompt
        , promptElement = el [ width fill ] (text "-- Select --")
        , itemToElement = itemToElement
        , itemToText = \_ -> ""
        , filterPlaceholder = Nothing
        , openButton = text "▼"
        , closeButton = text "▲"
        , containerAttributes = []
        , listAttributes = []
        , searchAttributes = []
        , selectAttributes = []
        }


{-| Create a filterable configuration. This takes:

    - itemsFromModel - The list of items to display in the dropdown (as a function of the model)
    - selectionFromModel - The function to get the selected item from the model
    - dropdownMsg - The message to wrap all the internal messages of the dropdown
    - onSelectMsg - A message to trigger when an item is selected
    - itemToPrompt - A function to get the Element to display from an item, to be used in the select part of the dropdown
    - itemToElement - A function that takes a bool for whether the item is selected followed by a bool for whether the item is highlighted, followed by the item and returns the Element to display, to be used in the list part of the dropdown
    - itemToText - A function to get the text representation from an item, to be used when filtering elements in the list

-}
filterable :
    { itemsFromModel : model -> List item
    , selectionFromModel : model -> Maybe item
    , dropdownMsg : Msg item -> msg
    , onSelectMsg : Maybe item -> msg
    , itemToPrompt : item -> Element msg
    , itemToElement : Bool -> Bool -> item -> Element msg
    , itemToText : item -> String
    }
    -> Config item msg model
filterable { itemsFromModel, selectionFromModel, dropdownMsg, onSelectMsg, itemToPrompt, itemToElement, itemToText } =
    Config
        { dropdownType = Filterable
        , itemsFromModel = itemsFromModel
        , selectionFromModel = selectionFromModel >> SingleItem
        , dropdownMsg = dropdownMsg
        , onSelectMsg = OnSelectSingleItem onSelectMsg
        , selectionToPrompt = SingleItemToPrompt itemToPrompt
        , promptElement = el [ width fill ] (text "-- Select --")
        , itemToElement = itemToElement
        , itemToText = itemToText
        , filterPlaceholder = Just "Filter values"
        , openButton = text "▼"
        , closeButton = text "▲"
        , containerAttributes = []
        , listAttributes = []
        , searchAttributes = []
        , selectAttributes = []
        }


{-| Sets the content of the Select, default is "-- Select --"

    Dropdown.withPromptElement (el [ Font.color (rgb255 123 123 123) ] <| text "Pick one") config

-}
withPromptElement : Element msg -> Config item msg model -> Config item msg model
withPromptElement promptElement (Config config) =
    Config { config | promptElement = promptElement }


{-| Sets the placeholder of the Filterable dropdown, default is "Filter values"

    Dropdown.withFilterPlaceholder "Type here..." config

-}
withFilterPlaceholder : String -> Config item msg model -> Config item msg model
withFilterPlaceholder placeholderString (Config config) =
    let
        placeholder =
            if String.isEmpty placeholderString then
                Nothing

            else
                Just placeholderString
    in
    Config { config | filterPlaceholder = placeholder }


{-| Sets the container visual attributes, default is empty

    Dropdown.withContainerAttributes [ width (px 300) ] config

-}
withContainerAttributes : List (Attribute msg) -> Config item msg model -> Config item msg model
withContainerAttributes attrs (Config config) =
    Config { config | containerAttributes = attrs }


{-| Sets the select visual attributes, default is empty

    Dropdown.withSelectAttributes [ Border.width 1, Border.rounded 5, paddingXY 16 8 ] config

-}
withSelectAttributes : List (Attribute msg) -> Config item msg model -> Config item msg model
withSelectAttributes attrs (Config config) =
    Config { config | selectAttributes = attrs }


{-| Sets the search visual attributes, default is empty

    Dropdown.withSearchAttributes [ Border.width 0, padding 0 ] config

-}
withSearchAttributes : List (Attribute msg) -> Config item msg model -> Config item msg model
withSearchAttributes attrs (Config config) =
    Config { config | searchAttributes = attrs }


{-| Sets the open and close buttons' visual attributes, default is empty

    Dropdown.withOpenCloseButtons { openButton = text "+", closeButton = "-" } config

-}
withOpenCloseButtons : { openButton : Element msg, closeButton : Element msg } -> Config item msg model -> Config item msg model
withOpenCloseButtons { openButton, closeButton } (Config config) =
    Config { config | openButton = openButton, closeButton = closeButton }


{-| Sets the item list visual attributes, default is empty

    Dropdown.withListAttributes [ Border.width 1, Border.rounded ] config

-}
withListAttributes : List (Attribute msg) -> Config item msg model -> Config item msg model
withListAttributes attrs (Config config) =
    Config { config | listAttributes = attrs }


{-| Update the component state

    DropdownMsg subMsg ->
        let
            ( updated, cmd ) =
                Dropdown.update dropdownConfig subMsg model model.dropdownState model.items
        in
            ( { model | dropdownState = updated }, cmd )

-}
update : Config item msg model -> Msg item -> model -> State item -> ( State item, Cmd msg )
update (Config config) msg model (State state) =
    let
        items =
            config.itemsFromModel model

        selectedItems =
            selectedItemsAsList config model

        ( newState, newCommand ) =
            case msg of
                NoOp ->
                    ( state, Cmd.none )

                OnBlur ->
                    ( { state | isOpen = closeOnlyIfNotMultiSelect config state }, Cmd.none )

                OnClickOutside ->
                    ( { state | isOpen = False }, Cmd.none )

                OnClickPrompt ->
                    let
                        isOpen =
                            not state.isOpen

                        cmd =
                            if isOpen then
                                Task.attempt (\_ -> NoOp) (Dom.focus (state.id ++ "input-search"))

                            else
                                Cmd.none
                    in
                    ( { state | isOpen = isOpen, focusedIndex = 0, filterText = "" }, Cmd.map config.dropdownMsg cmd )

                OnSelect item ->
                    let
                        selectedItemsNew =
                            selectedItems
                                |> modifySelectedItems config.dropdownType item
                    in
                    ( { state
                        | isOpen = closeOnlyIfNotMultiSelect config state
                      }
                    , updateSelectedItemsCommand config.onSelectMsg selectedItemsNew
                    )

                OnFilterTyped val ->
                    ( { state | filterText = val }, Cmd.none )

                OnKeyDown key ->
                    let
                        newIndex =
                            case key of
                                ArrowUp ->
                                    if state.focusedIndex > 0 then
                                        state.focusedIndex - 1

                                    else
                                        0

                                ArrowDown ->
                                    if state.focusedIndex < List.length items - 1 then
                                        state.focusedIndex + 1

                                    else
                                        List.length items - 1

                                _ ->
                                    state.focusedIndex

                        isOpen =
                            case key of
                                Esc ->
                                    False

                                Enter ->
                                    False

                                _ ->
                                    True

                        maybeFocusedItem =
                            items
                                |> List.indexedMap (\i item -> ( i, item ))
                                |> List.filter (\( i, _ ) -> i == state.focusedIndex)
                                |> List.head
                                |> Maybe.map Tuple.second

                        cmd =
                            case key of
                                Enter ->
                                    case maybeFocusedItem of
                                        Just focusedItem ->
                                            selectedItems
                                                |> modifySelectedItems config.dropdownType focusedItem
                                                |> updateSelectedItemsCommand config.onSelectMsg

                                        Nothing ->
                                            Cmd.none

                                _ ->
                                    Cmd.none
                    in
                    ( { state | focusedIndex = newIndex, isOpen = isOpen }, cmd )
    in
    ( State newState, newCommand )



-- update helpers


selectedItemsAsList : { a | selectionFromModel : model -> Selection item } -> model -> List item
selectedItemsAsList config model =
    case config.selectionFromModel model of
        SingleItem maybeItem ->
            maybeItem
                |> Maybe.map List.singleton
                |> Maybe.withDefault []

        MultipleItems listItems ->
            listItems


modifySelectedItems : DropdownType -> item -> List item -> List item
modifySelectedItems dropdownType selectedItem selectedItemsOld =
    case dropdownType of
        MultiSelect ->
            -- if it was selected, we remove it from the list, otherwise include it
            if List.any ((==) selectedItem) selectedItemsOld then
                List.filter ((/=) selectedItem) selectedItemsOld

            else
                selectedItem :: selectedItemsOld

        _ ->
            [ selectedItem ]


updateSelectedItemsCommand : OnSelectMsg item msg -> List item -> Cmd msg
updateSelectedItemsCommand onSelectMsg selectedItemsNew =
    let
        onSelectMsgWithItems =
            case onSelectMsg of
                OnSelectSingleItem itemToMsg ->
                    itemToMsg <| List.head <| selectedItemsNew

                OnSelectMultipleItems itemsToMsg ->
                    itemsToMsg <| selectedItemsNew
    in
    Task.succeed onSelectMsgWithItems |> Task.perform identity


closeOnlyIfNotMultiSelect : { a | dropdownType : DropdownType } -> { b | isOpen : Bool } -> Bool
closeOnlyIfNotMultiSelect config state =
    case config.dropdownType of
        MultiSelect ->
            state.isOpen

        _ ->
            False


{-| Render the view

    Dropdown.view dropdownConfig model model.dropdownState model.items

-}
view : Config item msg model -> model -> State item -> Element msg
view (Config config) model (State state) =
    let
        items =
            config.itemsFromModel model

        selectedItems =
            selectedItemsAsList config model

        containerAttrs =
            [ idAttr state.id
            , below body
            ]
                ++ config.containerAttributes

        filter item =
            String.contains (state.filterText |> String.toLower)
                (item |> config.itemToText |> String.toLower)

        filteredData =
            items
                |> List.filter filter

        trigger =
            triggerView config selectedItems state

        body =
            bodyView config selectedItems state filteredData
    in
    column
        containerAttrs
        [ el [ width fill ] trigger ]


triggerView : InternalConfig item msg model -> List item -> InternalState -> Element msg
triggerView config selectedItems state =
    let
        selectAttrs =
            [ onClick (config.dropdownMsg OnClickPrompt)
            , onKeyDown (config.dropdownMsg << OnKeyDown)
            , tabIndexAttr 0
            , referenceAttr state
            ]
                ++ (if config.dropdownType == Basic then
                        [ onBlurAttribute config state ]

                    else
                        []
                   )
                ++ config.selectAttributes

        prompt =
            el [ width fill ] <|
                case selectedItems of
                    [] ->
                        config.promptElement

                    xs ->
                        case config.selectionToPrompt of
                            SingleItemToPrompt f ->
                                case List.head xs of
                                    Nothing ->
                                        config.promptElement

                                    Just x ->
                                        f x

                            MultipleItemsToPrompt f ->
                                f xs

        search =
            case config.dropdownType of
                Basic ->
                    prompt

                MultiSelect ->
                    prompt

                Filterable ->
                    Input.search
                        ([ idAttr (state.id ++ "input-search")
                         , focused []
                         , onClickNoPropagation (config.dropdownMsg NoOp)
                         , onBlurAttribute config state
                         ]
                            ++ config.searchAttributes
                        )
                        { onChange = config.dropdownMsg << OnFilterTyped
                        , text = state.filterText
                        , placeholder =
                            config.filterPlaceholder
                                |> Maybe.map (text >> Input.placeholder [])
                        , label = Input.labelHidden "Filter List"
                        }

        ( promptOrSearch, button ) =
            if state.isOpen then
                ( search, el [] config.closeButton )

            else
                ( prompt, el [] config.openButton )
    in
    row selectAttrs [ promptOrSearch, button ]


bodyView : InternalConfig item msg model -> List item -> InternalState -> List item -> Element msg
bodyView config selectedItems state data =
    if state.isOpen then
        let
            items =
                column
                    config.listAttributes
                    (List.indexedMap (itemView config selectedItems state) data)

            body =
                el
                    [ htmlAttribute <| Html.Attributes.style "flex-shrink" "1"
                    , width fill
                    ]
                    items
        in
        body

    else
        none


itemView : InternalConfig item msg model -> List item -> InternalState -> Int -> item -> Element msg
itemView config selectedItems state i item =
    let
        itemAttrs =
            [ onClick <| config.dropdownMsg (OnSelect item)
            , referenceAttr state
            , tabIndexAttr -1
            , width fill
            ]

        selected =
            List.member item selectedItems

        highlighed =
            i == state.focusedIndex
    in
    el
        itemAttrs
        (config.itemToElement selected highlighed item)



-- view helpers


idAttr : String -> Attribute msg
idAttr id =
    Html.Attributes.id id
        |> htmlAttribute


tabIndexAttr : Int -> Attribute msg
tabIndexAttr tabIndex =
    Html.Attributes.tabindex tabIndex
        |> htmlAttribute


referenceDataName : String
referenceDataName =
    "data-dropdown-id"


referenceAttr : InternalState -> Attribute msg
referenceAttr model =
    Html.Attributes.attribute referenceDataName model.id
        |> htmlAttribute


onClick : msg -> Attribute msg
onClick message =
    Events.onClick message


onClickNoPropagation : msg -> Attribute msg
onClickNoPropagation msg =
    Html.Events.custom "click"
        (Decode.succeed
            { message = msg
            , stopPropagation = True
            , preventDefault = True
            }
        )
        |> htmlAttribute


onKeyDown : (Key -> msg) -> Attribute msg
onKeyDown msg =
    let
        stringToKey str =
            case str of
                "ArrowDown" ->
                    Decode.succeed ArrowDown

                "ArrowUp" ->
                    Decode.succeed ArrowUp

                "Enter" ->
                    Decode.succeed Enter

                "Escape" ->
                    Decode.succeed Esc

                _ ->
                    Decode.fail "not used key"

        keyDecoder =
            Decode.field "key" Decode.string
                |> Decode.andThen stringToKey
    in
    Html.Events.on "keydown" (Decode.map msg keyDecoder)
        |> htmlAttribute


onBlurAttribute : InternalConfig item msg model -> InternalState -> Attribute msg
onBlurAttribute config state =
    let
        -- relatedTarget only works if element has tabindex
        dataDecoder =
            Decode.at [ "relatedTarget", "attributes", referenceDataName, "value" ] Decode.string

        attrToMsg attr =
            if attr == state.id then
                config.dropdownMsg NoOp

            else
                config.dropdownMsg OnBlur

        blur =
            Decode.maybe dataDecoder
                |> Decode.map (Maybe.map attrToMsg)
                |> Decode.map (Maybe.withDefault <| config.dropdownMsg OnBlur)
    in
    Html.Events.on "blur" blur
        |> htmlAttribute


isOutsideDropdown : String -> Decode.Decoder Bool
isOutsideDropdown dropdownId =
    Decode.oneOf
        [ Decode.field "id" Decode.string
            |> Decode.andThen
                (\id ->
                    if dropdownId == id then
                        Decode.succeed False

                    else
                        Decode.fail "continue"
                )
        , Decode.lazy (\_ -> isOutsideDropdown dropdownId |> Decode.field "parentNode")
        , Decode.succeed True
        ]


{-| Emits the internal event 'OnClickOutside' and closes the multi select dropdown, works well with subscriptions. Takes:

    - dropdownId: Id of the HTML element from which you want to be notified whenever it is clicked outside!
    - dropdownMsg: The message to wrap all the internal messages of the dropdown

    subscriptions : Model -> Sub Msg
    subscriptions model =
        onMouseDown (Dropdown.outsideTarget "my-dropdown" DropdownMsg)

-}
outsideTarget : String -> (Msg item -> msg) -> Decode.Decoder msg
outsideTarget dropdownId dropdownMsg =
    Decode.field "target" (isOutsideDropdown dropdownId)
        |> Decode.andThen
            (\isOutside ->
                if isOutside then
                    Decode.succeed <| dropdownMsg OnClickOutside

                else
                    Decode.fail "inside dropdown"
            )


{-| Serves as a subscription to know when the user has clicked outside a certain dropdown

    - dropdownState: State of the dropdown we want to subscribe to
    - dropdownMsg: The message to wrap all the internal messages of the dropdown

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Dropdown.onOutsideClick model.dropdownState DropdownMsg

-}
onOutsideClick : State item -> (Msg item -> msg) -> Sub msg
onOutsideClick (State state) dropdownMsg =
    onMouseDown (outsideTarget state.id dropdownMsg)
