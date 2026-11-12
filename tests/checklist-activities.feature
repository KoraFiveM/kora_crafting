# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_crafting — Activities

  @kora_crafting @checklist @checklist:kora_crafting:creator-open @cat:activities @needs:admin
  Scenario: /craftCreator admin creator
    """
    Checklist test: As admin with 'command' ace run /craftCreator; NUI opens with Recipes and Stations tabs. Non-admin is denied.
    """
    When I run the command "/craftCreator"
    Then the "kora_crafting:creator" app opens
    And I confirm: the creator shows Recipes and Stations tabs
    When I manually: ask a second player without admin permission to run /craftCreator
    Then I confirm: the other player is denied access to the creator

  @kora_crafting @checklist @checklist:kora_crafting:create-recipe @cat:activities @needs:admin
  Scenario: Create a recipe
    """
    Checklist test: In creator, Create new recipe: set name, result item and amount, required items, progress text/time, animation; save.
    """
    When I manually: run /craftCreator
    Then the "kora_crafting:creator" app should be open
    When I manually: open the recipes grid
    And I manually: click Create new recipe
    And I manually: set the name, result item and amount
    And I manually: add the required items
    And I manually: set the progress text, progress time and animation
    And I manually: save the recipe
    Then I confirm: the new recipe is saved and appears in the recipes grid

  @kora_crafting @checklist @checklist:kora_crafting:recipe-keep-item @cat:activities @needs:admin @manual
  Scenario: Mark material as kept
    """
    Checklist test: Mark a required item as 'kept'; crafting needs it but does not consume it.
    """
    When I manually: run /craftCreator, edit a recipe, mark one required item as kept and save the recipe
    And I manually: craft the recipe at a station that has it, with all materials in my inventory
    Then I confirm: the craft succeeds and the kept item is still in my inventory
    And I confirm: the other required items were consumed

  @kora_crafting @checklist @checklist:kora_crafting:recipe-skill @cat:activities @needs:admin @manual
  Scenario: Recipe skill level and XP
    """
    Checklist test: Pick a kora_skills skill, level and xp on a recipe; below-level players see it locked, crafting grants XP.
    """
    When I manually: run /craftCreator, edit a recipe, pick a kora_skills skill, a required level and an xp amount, then save
    And I manually: ask a second player below the required level to open the station
    Then I confirm: the other player sees the recipe shown as locked
    When I manually: craft the recipe as a player with enough level
    Then I confirm: crafting grants the skill XP

  @kora_crafting @checklist @checklist:kora_crafting:create-station @cat:activities @needs:admin
  Scenario: Create a station
    """
    Checklist test: Create new station: name, target label/icon, add recipes, add locations by aiming; station target appears for players immediately.
    """
    When I manually: run /craftCreator
    Then the "kora_crafting:creator" app should be open
    When I manually: open the stations grid
    And I manually: click Create new station
    And I manually: set the name, target label and target icon
    And I manually: add recipes to the station
    And I manually: add a location by aiming at it and save
    Then I confirm: the station target appears immediately for players at that location

  @kora_crafting @checklist @checklist:kora_crafting:station-lock @cat:activities @needs:admin
  Scenario: Lock station to job or gang
    """
    Checklist test: Set a location to a job/gang; members can use it, others get 'You cannot use this station'.
    """
    When I manually: run /craftCreator, set a station location to a job or gang and save
    And I manually: ask a second player who is a member of that job or gang to use the station
    Then I confirm: the station opens for the other player
    When I manually: use the station as a player who is not a member
    Then I should see a notification containing "You cannot use this station"

  @kora_crafting @checklist @checklist:kora_crafting:station-object @cat:activities @needs:admin @manual
  Scenario: Station as spawned prop
    """
    Checklist test: Set a location to use an object; the prop spawns and is the interaction target instead of a zone.
    """
    When I manually: run /craftCreator, set a station location to use an object and save
    And I manually: go to that station location
    Then I confirm: the object prop is spawned at the location
    And I confirm: the prop is the interaction target instead of a zone

  @kora_crafting @checklist @checklist:kora_crafting:edit-delete @cat:activities @needs:admin
  Scenario: Edit/delete recipes and stations
    """
    Checklist test: Edit and delete a station and a recipe; deleting a recipe removes it from every station that had it; clients update live.
    """
    When I manually: run /craftCreator
    Then the "kora_crafting:creator" app should be open
    When I manually: edit a station and save
    And I manually: delete a station
    And I manually: edit a recipe that is on a station and save
    And I manually: delete a recipe that is on a station
    Then I confirm: the deleted recipe is removed from every station that had it
    And I confirm: clients see the changes live without reconnecting

  @kora_crafting @checklist @checklist:kora_crafting:open-station-menu @cat:activities
  Scenario: Use a station to open recipe cards
    """
    Checklist test: Target a station; cards show product, needs, missing items (red), skill/level, XP, split into 'Ready' and 'Missing something'.
    """
    When I manually: target a crafting station and use it
    Then the "kora_crafting:menu" app opens
    And I confirm: recipe cards show the product, needs, skill/level and XP
    And I confirm: missing items are shown in red
    And I confirm: recipes are split into 'Ready' and 'Missing something'

  @kora_crafting @checklist @checklist:kora_crafting:craft-item @cat:activities
  Scenario: Craft an item
    """
    Checklist test: With materials, click Craft; progress bar and animation run, materials removed and result item added with success notice.
    """
    When I manually: use a crafting station while holding all materials for a recipe
    And I manually: click Craft on that recipe
    Then a progress bar should run
    And I confirm: the animation runs during the progress bar
    And I confirm: the materials are removed from my inventory
    And I confirm: the result item is added to my inventory
    And I should see a notification containing "You made"

  @kora_crafting @checklist @checklist:kora_crafting:craft-missing-materials @cat:activities
  Scenario: Cannot craft without materials
    """
    Checklist test: Open station with missing materials; recipe appears under Missing and has no Craft button.
    """
    When I manually: use a crafting station while missing materials for a recipe
    Then the "kora_crafting:menu" app opens
    And I confirm: the recipe appears under Missing something
    And I confirm: the recipe has no Craft button

  @kora_crafting @checklist @checklist:kora_crafting:craft-cancel @cat:activities
  Scenario: Cancel crafting
    """
    Checklist test: Cancel the progress bar; no materials taken and no item given.
    """
    When I manually: use a crafting station with all materials and click Craft
    And I cancel the progress bar
    Then I confirm: no materials were taken from my inventory
    And I confirm: no result item was given

  @kora_crafting @checklist @checklist:kora_crafting:craft-no-room @cat:activities @manual
  Scenario: Inventory full refunds materials
    """
    Checklist test: Craft with no room for the result; 'no room' error and materials are returned.
    """
    When I manually: fill my inventory so the result item will not fit
    And I manually: use a crafting station with all materials and click Craft
    Then I confirm: I see a 'no room' error notification
    And I confirm: my materials are returned to my inventory

  @kora_crafting @checklist @checklist:kora_crafting:craft-skill-locked @cat:activities @manual
  Scenario: Level requirement blocks crafting
    """
    Checklist test: Try a recipe needing a higher skill level; shows 'Needs <skill> level N (you are level M)' and cannot craft.
    """
    When I manually: use a crafting station and pick a recipe that needs a higher skill level than mine
    Then I confirm: it shows 'Needs <skill> level N (you are level M)'
    And I confirm: I cannot craft the recipe

  @kora_crafting @checklist @checklist:kora_crafting:craft-distance @cat:activities @manual
  Scenario: Must stay near station
    """
    Checklist test: Walk away from the station before the bar ends or trigger remotely; server refuses (too far).
    """
    When I manually: start a craft at a station and walk away before the bar ends
    Then I confirm: the server refuses the craft because I am too far
    And I confirm: no result item is given and no materials are lost
    When I manually: trigger the craft remotely from far away, only if a dev tool allows it
    Then I confirm: the server refuses it as too far

  @kora_crafting @checklist @checklist:kora_crafting:craft-continuous @cat:activities
  Scenario: Menu reopens after crafting
    """
    Checklist test: After a craft finishes, the station menu reopens with updated stock so you can craft again.
    """
    When I manually: complete a craft at a station
    Then the "kora_crafting:menu" app opens
    And I confirm: the menu shows updated stock so I can craft again
