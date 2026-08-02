import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {ELEMENTS,SHAPES,WAVES,EVENTS,CLASSES,HEAT,FITTINGS,TALENTS,ARTICLES,makeSkill} from '../src/data.js';

test('the complete 9 x 4 combat matrix is constructible',()=>{
  assert.equal(Object.keys(SHAPES).length,9);
  assert.equal(Object.keys(ELEMENTS).length,4);
  const matrix=Object.keys(SHAPES).flatMap(s=>Object.keys(ELEMENTS).map(e=>makeSkill(s,e)));
  assert.equal(matrix.length,36);
  assert.equal(new Set(matrix.map(s=>`${s.shape}:${s.element}`)).size,36);
});

test('the Godot-facing progression surface is present',()=>{
  assert.equal(Object.keys(CLASSES).length,2);
  assert.equal(WAVES.length,12);
  assert.deepEqual([WAVES[3].event,WAVES[7].event,WAVES[11].event],['grapple','blackout','colossus']);
  assert.equal(Object.keys(EVENTS).length,3);
  assert.equal(HEAT.length,6);
  assert.equal(Object.keys(FITTINGS).length,6);
  assert.ok(Object.keys(TALENTS).length>=8);
  assert.ok(Object.keys(ARTICLES).length>=6);
});

test('the project remains isolated and has a browser entry point',async()=>{
  const html=await readFile(new URL('../index.html',import.meta.url),'utf8');
  const game=await readFile(new URL('../src/game.js',import.meta.url),'utf8');
  assert.match(html,/src\/game\.js/);
  assert.match(game,/localStorage/);
  assert.match(game,/window\.__skygear/);
  assert.match(game,/startWave\(1\)/);
});
